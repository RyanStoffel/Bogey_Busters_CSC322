import 'package:flutter/material.dart';
import 'package:golf_tracker_app/widgets/bottom_nav_bar.dart';

class ShellScreen extends StatelessWidget {
  final Widget body;
  final int currentIndex;

  const ShellScreen({
    super.key,
    required this.body,
    required this.currentIndex
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavBar(currentIndex: currentIndex),
    );
  }
}