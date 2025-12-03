import 'dart:math';

String getRandomCourseImage() {
  final random = Random();
  final imageNumber = random.nextInt(7) + 1; 
  if (imageNumber == 1) {
    return 'images/default1.png';
  } else {
    return 'images/default$imageNumber.png';
  }
}
