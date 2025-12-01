import 'package:flutter/material.dart';
import 'package:golf_tracker_app/models/user.dart';
import 'package:golf_tracker_app/services/friend_service.dart';

class UserSearchCard extends StatefulWidget {
  final User user;
  final VoidCallback? onRequestSent;

  const UserSearchCard({
    super.key,
    required this.user,
    this.onRequestSent,
  });

  @override
  State<UserSearchCard> createState() => _UserSearchCardState();
}

class _UserSearchCardState extends State<UserSearchCard> {
  final FriendService _friendService = FriendService();
  bool _isLoading = false;
  bool _isFriend = false;
  bool _requestSent = false;

  @override
  void initState() {
    super.initState();
    _checkFriendshipStatus();
  }

  Future<void> _checkFriendshipStatus() async {
    final isFriend = await _friendService.isFriend(widget.user.uid);
    final hasSentRequest = await _friendService.hasSentRequest(widget.user.uid);

    if (mounted) {
      setState(() {
        _isFriend = isFriend;
        _requestSent = hasSentRequest;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _friendService.sendFriendRequest(
        widget.user.uid,
        widget.user.displayName ?? widget.user.email,
      );

      if (mounted) {
        setState(() {
          _requestSent = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Friend request sent to ${widget.user.displayName ?? widget.user.email}'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onRequestSent?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.green,
              backgroundImage: widget.user.profilePictureUrl != null &&
                      widget.user.profilePictureUrl!.isNotEmpty
                  ? NetworkImage(widget.user.profilePictureUrl!)
                  : null,
              child: widget.user.profilePictureUrl == null ||
                      widget.user.profilePictureUrl!.isEmpty
                  ? Text(
                      _getInitials(widget.user.displayName ?? widget.user.email),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3E1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Add Friend Button
            if (_isFriend)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              )
            else if (_requestSent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: _isLoading ? null : _sendFriendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Add Friend',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
