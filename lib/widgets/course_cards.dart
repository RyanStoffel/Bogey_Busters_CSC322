import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:golf_tracker_app/models/course.dart';
import 'package:golf_tracker_app/services/location_service.dart';
import 'package:golf_tracker_app/services/friend_service.dart';

enum CourseCardType { courseScoreCard, friendCourseScoreCard, courseCard }

class CourseCard extends StatefulWidget {
  final CourseCardType type;
  final String courseName;
  final String courseImage;
  final int holes;
  final int par;
  final String? distance;
  final int? totalScore;
  final int? relativeToPar;
  final String? friendName;
  final Course? course;
  final VoidCallback? onPreview;
  final VoidCallback? onPlay;
  final VoidCallback? onDelete;
  final String? imageUrl;
  final double? courseLatitude;
  final double? courseLongitude;
  final String? scorecardId;
  final String? friendId;
  final String? roundId;

  const CourseCard({
    super.key,
    required this.type,
    required this.courseName,
    required this.courseImage,
    required this.holes,
    required this.par,
    this.distance,
    this.totalScore,
    this.relativeToPar,
    this.friendName,
    this.course,
    this.onPreview,
    this.onPlay,
    this.onDelete,
    this.imageUrl,
    this.courseLatitude,
    this.courseLongitude,
    this.scorecardId,
    this.friendId,
    this.roundId,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  final LocationService _locationService = LocationService();
  final FriendService _friendService = FriendService();
  late Future<String?> _distanceFuture;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.type == CourseCardType.courseCard &&
        widget.courseLatitude != null &&
        widget.courseLongitude != null) {
      _distanceFuture = _locationService.getDistanceToCourse(
        widget.courseLatitude!,
        widget.courseLongitude!,
      );
    } else {
      _distanceFuture = Future.value(null);
    }
    if (widget.type == CourseCardType.friendCourseScoreCard &&
        widget.friendId != null &&
        widget.roundId != null) {
      _loadLikesAndComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadLikesAndComments() async {
    if (widget.friendId == null || widget.roundId == null) return;

    final isLiked =
        await _friendService.hasLikedRound(widget.friendId!, widget.roundId!);
    final likesCount =
        await _friendService.getRoundLikesCount(widget.friendId!, widget.roundId!);
    final commentsCount =
        await _friendService.getRoundCommentsCount(widget.friendId!, widget.roundId!);

    if (mounted) {
      setState(() {
        _isLiked = isLiked;
        _likesCount = likesCount;
        _commentsCount = commentsCount;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (widget.friendId == null || widget.roundId == null) return;

    try {
      if (_isLiked) {
        await _friendService.unlikeRound(widget.friendId!, widget.roundId!);
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likesCount = _likesCount > 0 ? _likesCount - 1 : 0;
          });
        }
      } else {
        await _friendService.likeRound(widget.friendId!, widget.roundId!);
        if (mounted) {
          setState(() {
            _isLiked = true;
            _likesCount = _likesCount + 1;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showComments() {
    if (widget.friendId == null || widget.roundId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCommentsBottomSheet(),
    );
  }

  Widget _buildCommentsBottomSheet() {
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
                    Icon(Icons.comment, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Comments',
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

              // Comments list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friendService.getRoundComments(
                      widget.friendId!, widget.roundId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    final comments = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final profilePictureUrl = comment['userProfilePictureUrl'] as String?;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.green,
                                backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                                    ? NetworkImage(profilePictureUrl)
                                    : null,
                                child: profilePictureUrl == null || profilePictureUrl.isEmpty
                                    ? Text(
                                        _getInitials(comment['userName'] ?? 'U'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment['userName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['comment'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Comment input
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        cursorColor: Colors.green,
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.green, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.green.withOpacity(0.5)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.green,
                      onPressed: () async {
                        if (_commentController.text.trim().isEmpty) return;

                        try {
                          await _friendService.addComment(
                            widget.friendId!,
                            widget.roundId!,
                            _commentController.text,
                          );
                          _commentController.clear();
                          
                          // Update comment count
                          final newCount = await _friendService
                              .getRoundCommentsCount(
                                  widget.friendId!, widget.roundId!);
                          if (mounted) {
                            setState(() {
                              _commentsCount = newCount;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error adding comment: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Scorecard'),
          content: Text(
            'Are you sure you want to delete this scorecard for ${widget.courseName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(style: TextStyle(color: Colors.black), 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteScorecard();
    }
  }

  Future<void> _deleteScorecard() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || widget.scorecardId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to delete scorecard'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Delete from Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('rounds')
          .doc(widget.scorecardId)
          .delete();

      if (mounted) {
        // Call the onDelete callback to remove from UI
        widget.onDelete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scorecard deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting scorecard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1D4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildImage(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: widget.type == CourseCardType.courseCard
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.courseName, style: _textStyle(18, FontWeight.w700)),
                const SizedBox(height: 4),
                _buildDistanceRow(),
                const SizedBox(height: 4),
                Text('${widget.distance}', style: _textStyle(14, FontWeight.w400)),
              ],
            )
          : widget.type == CourseCardType.friendCourseScoreCard
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.friendName} Played at:',
                        style: _textStyle(16, FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${widget.courseName} - ${widget.holes} holes Par ${widget.par}',
                        style: _textStyle(14, FontWeight.w500)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.courseName, style: _textStyle(18, FontWeight.w800)),
                        //const SizedBox(height: 4),
                        Text('${widget.holes} holes Par ${widget.par}',
                            style: _textStyle(15, FontWeight.w400)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      iconSize: 20,
                      color: Colors.red,
                      onPressed: _showDeleteConfirmation,
                    )
                  ],
                ),
    );
  }

  Widget _buildDistanceRow() {
    return FutureBuilder<String?>(
      future: _distanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          return Row(
            children: [
              Icon(Icons.location_on, size: 16, color: const Color(0xFF6B8E4E)),
              const SizedBox(width: 4),
              Text('${snapshot.data} miles away', style: _textStyle(14, FontWeight.w400)),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildImage() {
    return LayoutBuilder(
      builder: (_, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                ? Image.network(
                    widget.imageUrl!,
                    height: constraints.maxWidth * 0.6,
                    width: constraints.maxWidth,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: constraints.maxWidth * 0.6,
                        width: constraints.maxWidth,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: constraints.maxWidth * 0.6,
                        width: constraints.maxWidth,
                        color: Colors.grey[300],
                        child: Icon(Icons.golf_course, size: 50, color: Colors.grey[600]),
                      );
                    },
                  )
                : Image.asset(
                    widget.courseImage,
                    height: constraints.maxWidth * 0.6,
                    width: constraints.maxWidth,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: constraints.maxWidth * 0.6,
                        width: constraints.maxWidth,
                        color: Colors.grey[300],
                        child: Icon(Icons.golf_course, size: 50, color: Colors.grey[600]),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: widget.type == CourseCardType.courseCard
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Par ${widget.par}', style: _textStyle(16, FontWeight.w600)),
                Text('${widget.holes} holes', style: _textStyle(14, FontWeight.w400)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildButton('Preview', isOutlined: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildButton('Play')),
                  ],
                ),
              ],
            )
          : widget.type == CourseCardType.friendCourseScoreCard
              ? Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildScoreItem('Total Score:', widget.totalScore.toString()),
                        _buildScoreItem('Relative to Par:',
                            '${widget.relativeToPar! >= 0 ? '+' : ''}${widget.relativeToPar}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : Colors.grey[600],
                                size: 24,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_likesCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        InkWell(
                          onTap: _showComments,
                          child: Row(
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_commentsCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildScoreItem('Total Score:', widget.totalScore.toString()),
                    _buildScoreItem('Relative to Par:',
                        '${widget.relativeToPar! >= 0 ? '+' : ''}${widget.relativeToPar}'),
                  ],
                ),
    );
  }

  Widget _buildScoreItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _textStyle(16, FontWeight.w400)),
        const SizedBox(height: 4),
        Text(value, style: _textStyle(20, FontWeight.w700)),
      ],
    );
  }

  Widget _buildButton(String text, {bool isOutlined = false}) {
    VoidCallback? onPressed;

    if (text == 'Preview') {
      onPressed = widget.onPreview;
    } else if (text == 'Play') {
      onPressed = widget.onPlay;
    }

    return isOutlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B8E4E),
              side: const BorderSide(color: Color(0xFF6B8E4E)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(text),
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E4E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(text),
          );
  }

  TextStyle _textStyle(double size, FontWeight weight) {
    return TextStyle(fontSize: size, fontWeight: weight, color: const Color(0xFF2D3E1F));
  }
}
