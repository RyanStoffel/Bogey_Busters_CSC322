import 'package:flutter/material.dart';
import 'package:golf_tracker_app/models/course.dart';
import 'package:golf_tracker_app/services/location_service.dart';

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
  final bool? hasCarts;
  final Course? course;
  final VoidCallback? onPreview;
  final VoidCallback? onPlay;
  final String? imageUrl;
  final double? courseLatitude;
  final double? courseLongitude;

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
    this.hasCarts,
    this.course,
    this.onPreview,
    this.onPlay,
    this.imageUrl,
    this.courseLatitude,
    this.courseLongitude,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  final LocationService _locationService = LocationService();
  String? _distanceFromUser;
  bool _isCalculatingDistance = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == CourseCardType.courseCard && 
        widget.courseLatitude != null && 
        widget.courseLongitude != null) {
      print('CourseCard initState: courseLat=${widget.courseLatitude}, courseLng=${widget.courseLongitude}');
      _calculateDistance();
    } else {
      print('CourseCard initState: NOT calculating distance - type=${widget.type}, lat=${widget.courseLatitude}, lng=${widget.courseLongitude}');
    }
  }

  Future<void> _calculateDistance() async {
    setState(() {
      _isCalculatingDistance = true;
    });

    print('CourseCard: Starting distance calculation...');
    final distanceInMiles = await _locationService.getDistanceToCourse(
      widget.courseLatitude!,
      widget.courseLongitude!,
    );

    print('CourseCard: Distance result = $distanceInMiles');

    if (mounted) {
      setState(() {
        _distanceFromUser = distanceInMiles;
        _isCalculatingDistance = false;
      });
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
                Text('${widget.distance} yards', style: _textStyle(14, FontWeight.w400)),
              ],
            )
          : widget.type == CourseCardType.friendCourseScoreCard
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.friendName} Played at:', style: _textStyle(16, FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${widget.courseName} - ${widget.holes} holes Par ${widget.par}', 
                         style: _textStyle(14, FontWeight.w500)),
                  ],
                )
              : Text('${widget.courseName} - ${widget.holes} holes Par ${widget.par}', 
                     style: _textStyle(14, FontWeight.w600)),
    );
  }

  Widget _buildDistanceRow() {
    if (_isCalculatingDistance) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6B8E4E)),
            ),
          ),
          const SizedBox(width: 8),
          Text('Calculating distance...', style: _textStyle(14, FontWeight.w400)),
        ],
      );
    }

    if (_distanceFromUser != null) {
      return Row(
        children: [
          Icon(Icons.location_on, size: 16, color: const Color(0xFF6B8E4E)),
          const SizedBox(width: 4),
          Text('$_distanceFromUser miles away', style: _textStyle(14, FontWeight.w400)),
        ],
      );
    }

    return const SizedBox.shrink();
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
                Text(widget.hasCarts! ? 'Carts' : 'No Carts', style: _textStyle(14, FontWeight.w400)),
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
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildScoreItem('Total Score:', widget.totalScore.toString()),
                _buildScoreItem('Relative to Par:', '${widget.relativeToPar! >= 0 ? '+' : ''}${widget.relativeToPar}'),
              ],
            ),
    );
  }

  Widget _buildScoreItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _textStyle(12, FontWeight.w400)),
        const SizedBox(height: 4),
        Text(value, style: _textStyle(18, FontWeight.w700)),
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