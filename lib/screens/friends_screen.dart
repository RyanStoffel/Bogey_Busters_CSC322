import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/user.dart';
import 'package:golf_tracker_app/services/friend_service.dart';
import 'package:golf_tracker_app/utils/image_helper.dart';
import 'package:golf_tracker_app/widgets/course_cards.dart';
import 'package:golf_tracker_app/widgets/user_search_card.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();

  List<User> _searchResults = [];
  List<Map<String, dynamic>> _friendsRounds = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  bool _isLoadingRounds = true;

  @override
  void initState() {
    super.initState();
    _loadFriendsRounds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendsRounds() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRounds = true;
    });

    // Get both friends' rounds and current user's rounds
    final friendsRounds = await _friendService.getFriendsRounds();
    final userRounds = await _friendService.getCurrentUserRounds();

    // Combine the rounds
    final allRounds = [...friendsRounds, ...userRounds];

    // Sort by date (most recent first)
    allRounds.sort((a, b) {
      final dateA = (a['round'] as dynamic).date;
      final dateB = (b['round'] as dynamic).date;
      return (dateB as DateTime).compareTo(dateA as DateTime);
    });

    if (mounted) {
      setState(() {
        _friendsRounds = allRounds;
        _isLoadingRounds = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;

    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingSearch = true;
        _isSearching = true;
      });
    }

    final results = await _friendService.searchUsers(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoadingSearch = false;
      });
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationsBottomSheet(),
    );
  }

  Widget _buildNotificationsBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E1F),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Notifications list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friendService.getReceivedFriendRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    final requests = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final type = request['type'];

                        Widget notificationWidget;
                        if (type == 'accepted') {
                          notificationWidget = _buildAcceptedNotification(request);
                        } else if (type == 'like') {
                          notificationWidget = _buildLikeNotification(request);
                        } else if (type == 'comment') {
                          notificationWidget = _buildCommentNotification(request);
                        } else {
                          notificationWidget = _buildFriendRequestNotification(request);
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: notificationWidget,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendRequestNotification(Map<String, dynamic> request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green,
              child: Text(
                _getInitials(request['fromUserName'] ?? 'U'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request['fromUserName']} sent you a friend request',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3E1F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () async {
                await _friendService.declineFriendRequest(request['fromUserId']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request declined')),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Decline'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                await _friendService.acceptFriendRequest(request['fromUserId']);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('You are now friends with ${request['fromUserName']}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadFriendsRounds(); // Refresh the friends rounds
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcceptedNotification(Map<String, dynamic> request) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.green,
          child: const Icon(Icons.check, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${request['fromUserName']} accepted your friend request!',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3E1F),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () async {
            await _friendService.clearAcceptedNotification(request['fromUserId']);
          },
        ),
      ],
    );
  }

  Widget _buildLikeNotification(Map<String, dynamic> request) {
    return InkWell(
      onTap: () {
        // Close the notification modal
        Navigator.of(context).pop();
        // The round should be visible in the feed below
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check the feed for your round at ${request['courseName']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.red,
            child: const Icon(Icons.favorite, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${request['fromUserName']} liked your round at ${request['courseName']}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3E1F),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () async {
              await _friendService.clearNotification(request['fromUserId'], request['type'], request['timestamp']);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentNotification(Map<String, dynamic> request) {
    return InkWell(
      onTap: () {
        // Close the notification modal
        Navigator.of(context).pop();
        // The round should be visible in the feed below
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check the feed for your round at ${request['courseName']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.comment, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${request['fromUserName']} commented on your round at ${request['courseName']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3E1F),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () async {
                  await _friendService.clearNotification(request['fromUserId'], request['type'], request['timestamp']);
                },
              ),
            ],
          ),
          if (request['comment'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${request['comment']}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        leading: IconButton(
          icon: const Icon(Icons.people),
          onPressed: () {
            context.push('/friends/manage').then((_) => _loadFriendsRounds());
          },
        ),
        actions: [
          StreamBuilder<int>(
            stream: _friendService.getPendingRequestsCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;

              return IconButton(
                icon: count > 0
                    ? badges.Badge(
                        badgeContent: Text(
                          count.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        badgeStyle: const badges.BadgeStyle(
                          badgeColor: Colors.red,
                        ),
                        child: const Icon(Icons.notifications),
                      )
                    : const Icon(Icons.notifications_outlined),
                onPressed: _showNotifications,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              cursorColor: Colors.green,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.green),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5)),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
          ),

          // Content
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildFriendsRoundsFeed(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoadingSearch) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return UserSearchCard(
          user: _searchResults[index],
          onRequestSent: () {
            // Optionally refresh or update UI
          },
        );
      },
    );
  }

  Widget _buildFriendsRoundsFeed() {
    if (_isLoadingRounds) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsRounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.golf_course, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No rounds yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Play a round or add friends to see rounds here!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriendsRounds,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _friendsRounds.length,
        itemBuilder: (context, index) {
          final data = _friendsRounds[index];
          final round = data['round'];
          final friendName = data['friendName'];
          final friendId = data['friendId'];
          final roundId = round.roundId;

          return CourseCard(
            type: CourseCardType.friendCourseScoreCard,
            courseName: round.courseName,
            courseImage: getRandomCourseImage(),
            holes: round.holes?.length ?? 0,
            par: round.totalPar ?? 0,
            totalScore: round.totalScore,
            relativeToPar: round.relativeToPar,
            friendName: friendName,
            friendId: friendId,
            roundId: roundId,
          );
        },
      ),
    );
  }
}
