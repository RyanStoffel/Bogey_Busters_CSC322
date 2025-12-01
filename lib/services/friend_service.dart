import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:golf_tracker_app/models/round.dart';
import 'package:golf_tracker_app/models/user.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Search for users by display name or real name (excluding current user)
  Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty || currentUserId == null) return [];

    try {
      final queryLower = query.toLowerCase();

      // Get all users
      final snapshot = await _firestore.collection('users').get();
      print('Found ${snapshot.docs.length} total users in database');

      // Filter locally to exclude current user and match query
      final users = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) {
            try {
              final data = doc.data();
              return User.fromJson(data);
            } catch (e) {
              print('Error parsing user ${doc.id}: $e');
              return null;
            }
          })
          .where((user) => user != null)
          .cast<User>()
          .where((user) {
            final displayName = user.displayName?.toLowerCase() ?? '';
            final email = user.email.toLowerCase();
            final matches = displayName.contains(queryLower) || email.contains(queryLower);
            return matches;
          })
          .toList();

      print('Search for "$query" found ${users.length} matching users');
      return users;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Send a friend request
  Future<void> sendFriendRequest(String toUserId, String toUserName) async {
    if (currentUserId == null) return;

    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['displayName'] ?? 'Someone';

      // Add to recipient's receivedFriendRequests array
      await _firestore.collection('users').doc(toUserId).update({
        'receivedFriendRequests': FieldValue.arrayUnion([
          {
            'fromUserId': currentUserId,
            'fromUserName': currentUserName,
          }
        ])
      });

      print('Friend request sent to $toUserName');
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(String fromUserId) async {
    if (currentUserId == null) return;

    try {
      final batch = _firestore.batch();

      // Add to both users' friends arrays
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final friendUserRef = _firestore.collection('users').doc(fromUserId);

      batch.update(currentUserRef, {
        'friends': FieldValue.arrayUnion([fromUserId]),
      });

      batch.update(friendUserRef, {
        'friends': FieldValue.arrayUnion([currentUserId]),
      });

      await batch.commit();

      // Remove from receivedFriendRequests
      await _removeReceivedFriendRequest(fromUserId);

      // Notify the sender (add to their receivedFriendRequests as acceptance notification)
      final currentUserDoc = await currentUserRef.get();
      final currentUserName = currentUserDoc.data()?['displayName'] ?? 'Someone';

      await friendUserRef.update({
        'receivedFriendRequests': FieldValue.arrayUnion([
          {
            'fromUserId': currentUserId,
            'fromUserName': currentUserName,
            'type': 'accepted',
          }
        ])
      });

      print('Friend request accepted');
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  // Decline a friend request
  Future<void> declineFriendRequest(String fromUserId) async {
    if (currentUserId == null) return;

    try {
      await _removeReceivedFriendRequest(fromUserId);
      print('Friend request declined');
    } catch (e) {
      print('Error declining friend request: $e');
      rethrow;
    }
  }

  // Remove a friend request from receivedFriendRequests
  Future<void> _removeReceivedFriendRequest(String fromUserId) async {
    if (currentUserId == null) return;

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final requests =
        List<Map<String, dynamic>>.from(userDoc.data()?['receivedFriendRequests'] ?? []);

    // Remove the request with matching fromUserId
    requests.removeWhere((req) => req['fromUserId'] == fromUserId);

    await _firestore.collection('users').doc(currentUserId).update({
      'receivedFriendRequests': requests,
    });
  }

  // Get list of friends
  Future<List<User>> getFriends() async {
    if (currentUserId == null) return [];

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);

      if (friendIds.isEmpty) return [];

      final friends = <User>[];
      for (final friendId in friendIds) {
        final friendDoc = await _firestore.collection('users').doc(friendId).get();
        if (friendDoc.exists) {
          final data = friendDoc.data()!;
          // Add the uid from the document ID if not present
          data['uid'] = friendId;
          friends.add(User.fromJson(data));
        }
      }

      return friends;
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  // Get all rounds from friends sorted by date (most recent first)
  Future<List<Map<String, dynamic>>> getFriendsRounds() async {
    if (currentUserId == null) {
      print('getFriendsRounds: No current user');
      return [];
    }

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);

      print('getFriendsRounds: Found ${friendIds.length} friends: $friendIds');

      if (friendIds.isEmpty) return [];

      final allRounds = <Map<String, dynamic>>[];

      // Get rounds from each friend
      for (final friendId in friendIds) {
        final friendDoc = await _firestore.collection('users').doc(friendId).get();
        final friendName = friendDoc.data()?['displayName'] ?? 'Friend';

        print('Getting rounds for friend: $friendName ($friendId)');

        // Get all rounds (don't filter by isCompleted since it's not set in Firebase)
        final roundsSnapshot = await _firestore
            .collection('users')
            .doc(friendId)
            .collection('rounds')
            .orderBy('timestamp', descending: true)
            .get();

        print('Found ${roundsSnapshot.docs.length} rounds for $friendName');

        for (final roundDoc in roundsSnapshot.docs) {
          try {
            final roundData = roundDoc.data();

            // Skip rounds that don't have score data
            if (roundData['score'] == null && roundData['totalScore'] == null) {
              continue;
            }

            // Map Firebase fields to Round model fields
            final mappedData = {
              'roundId': roundDoc.id,
              'userId': friendId,
              'courseId': roundData['courseId'] ?? '',
              'courseName': roundData['courseName'] ?? 'Unknown Course',
              'date': roundData['timestamp'] != null
                  ? (roundData['timestamp'] as Timestamp).toDate().toIso8601String()
                  : DateTime.now().toIso8601String(),
              'holes': roundData[
                  'holesData'], // Use holesData array, not holes (which is an int)
              'totalScore': roundData['score'] ?? roundData['totalScore'],
              'totalPar': roundData['par'] ?? roundData['totalPar'],
              'relativeToPar': roundData['relativeToPar'],
              'teeColor': roundData['teeColor'],
              'isCompleted': true, // Assume all saved rounds are completed
            };

            allRounds.add({
              'round': Round.fromJson(mappedData),
              'friendName': friendName,
              'friendId': friendId,
            });
          } catch (e) {
            print('Error parsing round ${roundDoc.id}: $e');
            // Skip this round and continue with others
            continue;
          }
        }
      }

      print('Total rounds from all friends: ${allRounds.length}');

      // Sort by date (most recent first)
      allRounds.sort((a, b) {
        final dateA = (a['round'] as Round).date;
        final dateB = (b['round'] as Round).date;
        return dateB.compareTo(dateA);
      });

      return allRounds;
    } catch (e) {
      print('Error getting friends rounds: $e');
      return [];
    }
  }

  // Stream of received friend requests
  Stream<List<Map<String, dynamic>>> getReceivedFriendRequests() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore.collection('users').doc(currentUserId).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data();
      if (data == null) return [];

      final requests = data['receivedFriendRequests'];
      if (requests == null) return [];

      return List<Map<String, dynamic>>.from(requests);
    });
  }

  // Get count of all notifications (excluding only accepted friend requests)
  Stream<int> getPendingRequestsCount() {
    return getReceivedFriendRequests().map((requests) {
      // Count all notifications except 'accepted' type
      return requests.length;
    });
  }

  // Clear an accepted notification
  Future<void> clearAcceptedNotification(String fromUserId) async {
    if (currentUserId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final requests = List<Map<String, dynamic>>.from(
          userDoc.data()?['receivedFriendRequests'] ?? []);

      // Remove the accepted notification with matching fromUserId
      requests.removeWhere(
          (req) => req['fromUserId'] == fromUserId && req['type'] == 'accepted');

      await _firestore.collection('users').doc(currentUserId).update({
        'receivedFriendRequests': requests,
      });
    } catch (e) {
      print('Error clearing notification: $e');
    }
  }

  // Clear a specific notification by type and timestamp
  Future<void> clearNotification(String fromUserId, String type, String? timestamp) async {
    if (currentUserId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final requests = List<Map<String, dynamic>>.from(
          userDoc.data()?['receivedFriendRequests'] ?? []);

      // Remove the notification with matching criteria
      requests.removeWhere((req) =>
          req['fromUserId'] == fromUserId &&
          req['type'] == type &&
          (timestamp == null || req['timestamp'] == timestamp));

      await _firestore.collection('users').doc(currentUserId).update({
        'receivedFriendRequests': requests,
      });
    } catch (e) {
      print('Error clearing notification: $e');
    }
  }

  // Check if already friends with a user
  Future<bool> isFriend(String userId) async {
    if (currentUserId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);
      return friendIds.contains(userId);
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  // Check if already sent a friend request to a user
  Future<bool> hasSentRequest(String userId) async {
    if (currentUserId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final requests = List<Map<String, dynamic>>.from(
          userDoc.data()?['receivedFriendRequests'] ?? []);
      return requests.any((req) => req['fromUserId'] == currentUserId);
    } catch (e) {
      print('Error checking sent request: $e');
      return false;
    }
  }

  // Remove a friend
  Future<void> removeFriend(String friendId) async {
    if (currentUserId == null) return;

    try {
      final batch = _firestore.batch();

      // Remove from both users' friends arrays
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final friendUserRef = _firestore.collection('users').doc(friendId);

      batch.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([friendId]),
      });

      batch.update(friendUserRef, {
        'friends': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();

      print('Friend removed successfully');
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  // Like a friend's round
  Future<void> likeRound(String friendId, String roundId) async {
    if (currentUserId == null) return;

    try {
      final roundRef = _firestore
          .collection('users')
          .doc(friendId)
          .collection('rounds')
          .doc(roundId);

      // Get the round first to check if likes field exists
      final roundDoc = await roundRef.get();
      if (!roundDoc.exists) {
        throw Exception('Round not found');
      }

      // Get current user info for notification
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['displayName'] ?? 'Someone';
      final courseName = roundDoc.data()?['courseName'] ?? 'a course';

      final data = roundDoc.data();
      if (data != null && data['likes'] == null) {
        // Initialize likes array if it doesn't exist
        await roundRef.set({
          'likes': [currentUserId]
        }, SetOptions(merge: true));
      } else {
        // Add to existing likes array
        await roundRef.update({
          'likes': FieldValue.arrayUnion([currentUserId])
        });
      }

      // Send notification to the round owner
      await _firestore.collection('users').doc(friendId).update({
        'receivedFriendRequests': FieldValue.arrayUnion([
          {
            'fromUserId': currentUserId,
            'fromUserName': currentUserName,
            'type': 'like',
            'roundId': roundId,
            'courseName': courseName,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ])
      });

      print('Round liked');
    } catch (e) {
      print('Error liking round: $e');
      rethrow;
    }
  }

  // Unlike a friend's round
  Future<void> unlikeRound(String friendId, String roundId) async {
    if (currentUserId == null) return;

    try {
      final roundRef = _firestore
          .collection('users')
          .doc(friendId)
          .collection('rounds')
          .doc(roundId);

      await roundRef.update({
        'likes': FieldValue.arrayRemove([currentUserId])
      });

      print('Round unliked');
    } catch (e) {
      print('Error unliking round: $e');
      rethrow;
    }
  }

  // Check if current user has liked a round
  Future<bool> hasLikedRound(String friendId, String roundId) async {
    if (currentUserId == null) return false;

    try {
      final roundDoc = await _firestore
          .collection('users')
          .doc(friendId)
          .collection('rounds')
          .doc(roundId)
          .get();

      if (!roundDoc.exists) return false;

      final likes = List<String>.from(roundDoc.data()?['likes'] ?? []);
      return likes.contains(currentUserId);
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  // Get likes count for a round
  Future<int> getRoundLikesCount(String friendId, String roundId) async {
    try {
      final roundDoc = await _firestore
          .collection('users')
          .doc(friendId)
          .collection('rounds')
          .doc(roundId)
          .get();

      if (!roundDoc.exists) return 0;

      final likes = List<String>.from(roundDoc.data()?['likes'] ?? []);
      return likes.length;
    } catch (e) {
      print('Error getting likes count: $e');
      return 0;
    }
  }

  // Add a comment to a friend's round
  Future<void> addComment(
      String friendId, String roundId, String comment) async {
    if (currentUserId == null || comment.trim().isEmpty) return;

    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data();
      final currentUserName = currentUserData?['displayName'] ?? 'Someone';
      final currentUserProfilePictureUrl = currentUserData?['profilePictureUrl'] as String?;

      final roundRef = _firestore
          .collection('users')
          .doc(friendId)
          .collection('rounds')
          .doc(roundId);

      // Get the round first to check if comments field exists
      final roundDoc = await roundRef.get();
      if (!roundDoc.exists) {
        throw Exception('Round not found');
      }

      final courseName = roundDoc.data()?['courseName'] ?? 'a course';

      final newComment = {
        'userId': currentUserId,
        'userName': currentUserName,
        'userProfilePictureUrl': currentUserProfilePictureUrl,
        'comment': comment.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final data = roundDoc.data();
      if (data != null && data['comments'] == null) {
        // Initialize comments array if it doesn't exist
        await roundRef.set({
          'comments': [newComment]
        }, SetOptions(merge: true));
      } else {
        // Add to existing comments array
        await roundRef.update({
          'comments': FieldValue.arrayUnion([newComment])
        });
      }

      // Send notification to the round owner
      await _firestore.collection('users').doc(friendId).update({
        'receivedFriendRequests': FieldValue.arrayUnion([
          {
            'fromUserId': currentUserId,
            'fromUserName': currentUserName,
            'type': 'comment',
            'roundId': roundId,
            'courseName': courseName,
            'comment': comment.trim().length > 50 
                ? '${comment.trim().substring(0, 50)}...' 
                : comment.trim(),
            'timestamp': DateTime.now().toIso8601String(),
          }
        ])
      });

      print('Comment added');
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for a round
  Stream<List<Map<String, dynamic>>> getRoundComments(
      String friendId, String roundId) {
    return _firestore
        .collection('users')
        .doc(friendId)
        .collection('rounds')
        .doc(roundId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];

      final comments = doc.data()?['comments'];
      if (comments == null) return [];

      return List<Map<String, dynamic>>.from(comments);
    });
  }

  // Get comments count for a round
  Future<int> getRoundCommentsCount(String friendId, String roundId) async {
    try {
      final roundDoc = await _firestore
          .collection('users')
          .doc(friendId)
          .collection('rounds')
          .doc(roundId)
          .get();

      if (!roundDoc.exists) return 0;

      final comments = List<dynamic>.from(roundDoc.data()?['comments'] ?? []);
      return comments.length;
    } catch (e) {
      print('Error getting comments count: $e');
      return 0;
    }
  }
}
