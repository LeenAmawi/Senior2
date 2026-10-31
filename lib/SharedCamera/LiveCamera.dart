import 'package:flutter/material.dart';

import 'package:senior2/ParentScreens/ParentDashboard.dart';
import 'package:senior2/ParentScreens/ParentProfile.dart';

class LiveCamera extends StatelessWidget {
  const LiveCamera({super.key});

  static const Color purple = Color(0xFFAA6BD5);
  static const Color background = Color(0xFFF1F0F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Live camera',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF292929),
            borderRadius: BorderRadius.circular(22),
          ),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: 55,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Camera stream is not connected',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        height: 65,
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: _navItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: false,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentDashboard(),
                    ),
                  );
                },
              ),
            ),

            Expanded(
              child: _navItem(
                icon: Icons.videocam_outlined,
                label: 'Camera',
                selected: true,
                onTap: () {},
              ),
            ),

            Expanded(
              child: _navItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: false,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentProfile(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation Item
  Widget _navItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0E2FA)
              : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF9B55D5),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9B55D5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}