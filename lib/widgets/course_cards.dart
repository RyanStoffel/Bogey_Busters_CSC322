import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:golf_tracker_app/models/course.dart';
import 'package:golf_tracker_app/services/location_service.dart';
import 'package:golf_tracker_app/services/friend_service.dart';
import 'package:golf_tracker_app/services/favorites_service.dart';

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

class _CourseCardState extends State<CourseCard> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final FriendService _friendService = FriendService();
  final FavoritesService _favoritesService = FavoritesService();
  late Future<String?> _distanceFuture;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isFavorite = false;
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize favorite animation controller
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _favoriteAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _favoriteAnimationController,
        curve: Curves.easeInOut,
      ),
    );

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

    // Load favorite status for course cards
    if (widget.type == CourseCardType.courseCard && widget.course != null) {
      _loadFavoriteStatus();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _favoriteAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    if (widget.course == null) return;

    final isFavorite = await _favoritesService.isFavoriteCourse(widget.course!.courseId);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.course == null) return;

    final newStatus = await _favoritesService.toggleFavorite(widget.course!.courseId);

    // Animate the heart
    _favoriteAnimationController.forward().then((_) {
      _favoriteAnimationController.reverse();
    });

    if (mounted) {
      setState(() {
        _isFavorite = newStatus;
      });
    }
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
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.comment, color: Color(0xFF0A5D2A)),
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
                                size: 64, color: Colors.grey.withOpacity(0.6)),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey.withOpacity(0.8)),
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
                                backgroundColor: Color(0xFF0A5D2A),
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
                        cursorColor: Color(0xFF0A5D2A),
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFF0A5D2A)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFF0A5D2A), width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Color(0xFF0A5D2A).withOpacity(0.5)),
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
                      color: Color(0xFF0A5D2A),
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
              child: const Text(style: TextStyle(color: Color(0xFF2D3E1F)), 'Cancel'),
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
      child: InkWell(
        onTap: widget.type == CourseCardType.courseCard ? widget.onPreview : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
      ),
    );
  }

  Widget _buildHeader() {
    return widget.type == CourseCardType.courseCard
        ? const SizedBox.shrink() // No header for course cards
        : Padding(
            padding: const EdgeInsets.all(16),
            child: widget.type == CourseCardType.friendCourseScoreCard
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

  Widget _buildImage() {
    return LayoutBuilder(
      builder: (_, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                            color: Colors.grey[100],
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
                            color: Colors.grey[100],
                            child: Icon(Icons.golf_course, size: 50, color: Colors.grey),
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
                            color: Colors.grey[100],
                            child: Icon(Icons.golf_course, size: 50, color: Colors.grey),
                          );
                        },
                      ),
              ),
              // Heart icon for favorites (only for course cards)
              if (widget.type == CourseCardType.courseCard)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ScaleTransition(
                    scale: _favoriteAnimation,
                    child: GestureDetector(
                      onTap: () {
                        _toggleFavorite();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF2D3E1F).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red.shade600 : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
                // Stats row: "18 Holes • Par 72 • 2.3 Miles"
                FutureBuilder<String?>(
                  future: _distanceFuture,
                  builder: (context, snapshot) {
                    final distance = snapshot.data ?? '';
                    final distanceText = distance.isNotEmpty ? ' • $distance miles' : '';

                    return Text(
                      '${widget.holes} Holes • Par ${widget.par}$distanceText',
                      style: _textStyle(13, FontWeight.w500).copyWith(
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Course name (biggest and bold)
                Text(
                  widget.courseName,
                  style: _textStyle(20, FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Location (city, state)
                Text(
                  '${widget.distance}',
                  style: _textStyle(14, FontWeight.w400).copyWith(
                    color: Colors.grey,
                  ),
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
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked ? Colors.red.shade600 : Colors.grey,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_likesCount',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF2D3E1F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: _showComments,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  color: Colors.grey,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_commentsCount',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF2D3E1F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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

  TextStyle _textStyle(double size, FontWeight weight) {
    return TextStyle(fontSize: size, fontWeight: weight, color: Color(0xFF2D3E1F));
  }
}
