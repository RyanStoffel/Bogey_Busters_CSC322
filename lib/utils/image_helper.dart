import 'dart:math';

String getRandomCourseImage() {
  final random = Random();
  final imageNumber = random.nextInt(8) + 1; 
  if (imageNumber == 1) {
    return 'images/default.png';
  } else {
    return 'images/default$imageNumber.png';
  }
}
