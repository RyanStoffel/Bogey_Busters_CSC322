import 'package:flutter/material.dart';
import 'package:golf_tracker_app/models/course.dart';

enum CourseCardType { courseScoreCard, friendCourseScoreCard, courseCard }

class CourseCard extends StatelessWidget {
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
  final VoidCallback? onPlay;
  final String? imageUrl;

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
    this.onPlay,
    this.imageUrl,
  });

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
      child: type == CourseCardType.courseCard
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courseName, style: _textStyle(18, FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$distance yards', style: _textStyle(14, FontWeight.w400)),
              ],
            )
          : type == CourseCardType.friendCourseScoreCard
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$friendName Played at:', style: _textStyle(16, FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('$courseName - $holes holes Par $par', style: _textStyle(14, FontWeight.w500)),
                  ],
                )
              : Text('$courseName - $holes holes Par $par', style: _textStyle(14, FontWeight.w600)),
    );
  }

  Widget _buildImage() {
    return LayoutBuilder(
      builder: (_, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
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
                    courseImage,
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
      child: type == CourseCardType.courseCard
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Par $par', style: _textStyle(16, FontWeight.w600)),
                Text('$holes holes', style: _textStyle(14, FontWeight.w400)),
                Text(hasCarts! ? 'Carts' : 'No Carts', style: _textStyle(14, FontWeight.w400)),
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
                _buildScoreItem('Total Score:', totalScore.toString()),
                _buildScoreItem('Relative to Par:', '${relativeToPar! >= 0 ? '+' : ''}$relativeToPar'),
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
    final isPlayButton = text == 'Play';
    final onPressed = isPlayButton && !isOutlined ? onPlay : () {};
    
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