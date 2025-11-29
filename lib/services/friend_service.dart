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

      // Filter locally to exclude current user and match query
      final users = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) {
            try {
              final data = doc.data();
              // Convert Timestamp to String for createdAt if it exists
              if (data['createdAt'] is Timestamp) {
                data['createdAt'] =
                    (data['createdAt'] as Timestamp).toDate().toIso8601String();
              }
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
            return displayName.contains(queryLower) || email.contains(queryLower);
          })
          .toList();

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
          friends.add(User.fromJson(friendDoc.data()!));
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

  // Get count of pending friend requests (excluding accepted notifications)
  Stream<int> getPendingRequestsCount() {
    return getReceivedFriendRequests().map((requests) {
      return requests.where((req) => req['type'] != 'accepted').length;
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
}
