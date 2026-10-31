
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ParentDashboard.dart';
import 'package:senior2/SharedCamera/LiveCamera.dart';
import 'SettingsPage.dart';

class ParentProfile extends StatelessWidget {
  const ParentProfile({super.key});

  static const Color purple = Color(0xFFAA6BD5);
  static const Color background = Color(0xFFF1F0F6);

  // Calculate age from birth date
  String calculateAge(DateTime birthDate) {
    final today = DateTime.now();

    int months =
        (today.year - birthDate.year) * 12 +
            today.month -
            birthDate.month;

    if (today.day < birthDate.day) {
      months--;
    }

    if (months < 0) {
      return 'Not available';
    }

    if (months < 12) {
      return '$months months';
    }

    final years = months ~/ 12;
    final remainingMonths = months % 12;

    if (remainingMonths == 0) {
      return '$years years';
    }

    return '$years years, $remainingMonths months';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in first')),
      );
    }

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Profile'),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parents')
            .doc(user.uid)
            .snapshots(),

        builder: (context, parentSnapshot) {
          if (parentSnapshot.hasError) {
            return const Center(
              child: Text('Something went wrong'),
            );
          }

          if (parentSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!parentSnapshot.hasData ||
              !parentSnapshot.data!.exists) {
            return const Center(
              child: Text('Parent data not found'),
            );
          }

          final parentData =
          parentSnapshot.data!.data() as Map<String, dynamic>;

          final childIds = List<String>.from(
            parentData['childIds'] ?? [],
          );

          if (childIds.isEmpty) {
            return const Center(
              child: Text('No child linked to this account'),
            );
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('children')
                .doc(childIds.first)
                .snapshots(),

            builder: (context, childSnapshot) {
              if (childSnapshot.hasError) {
                return const Center(
                  child: Text('Could not load child data'),
                );
              }

              if (childSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!childSnapshot.hasData ||
                  !childSnapshot.data!.exists) {
                return const Center(
                  child: Text('Child not found'),
                );
              }

              final childData =
              childSnapshot.data!.data() as Map<String, dynamic>;

              final name =
                  childData['name']?.toString() ?? 'Child';

              // Get birthDate from Firebase
              final birthDateValue = childData['birthDate'];

              DateTime? birthDate;

              if (birthDateValue is Timestamp) {
                birthDate = birthDateValue.toDate();
              } else if (birthDateValue is String) {
                birthDate = DateTime.tryParse(birthDateValue);
              }

              // Calculate age automatically
              final ageText = birthDate != null
                  ? calculateAge(birthDate)
                  : 'Not available';

              final birthDateText = birthDate != null
                  ? '${birthDate.day}/${birthDate.month}/${birthDate.year}'
                  : 'Not available';

              final nfcId =
                  childData['nfcId']?.toString() ?? 'Not available';

              // Image path from Firebase
              final photoUrl =
                  childData['photoUrl']?.toString() ?? '';

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 20),

                  // Child image from Firebase asset path
                  CircleAvatar(
                    radius: 62,
                    backgroundColor: const Color(0xFF8961A9),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? Image.asset(
                        photoUrl,
                        width: 124,
                        height: 124,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Image error: $error');

                          return const Icon(
                            Icons.child_care,
                            color: Colors.white,
                            size: 75,
                          );
                        },
                      )
                          : const Icon(
                        Icons.child_care,
                        color: Colors.white,
                        size: 75,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    ageText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 25),

                  _infoCard(
                    icon: Icons.nfc,
                    title: 'NFC ID',
                    value: nfcId,
                  ),

                  const SizedBox(height: 14),

                  _infoCard(
                    icon: Icons.calendar_today,
                    title: 'Birth Date',
                    value: birthDateText,
                  ),

                  const SizedBox(height: 14),

                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                    child: _infoCard(
                      icon: Icons.settings,
                      title: 'Settings',
                      value: '',
                      showArrow: true,
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();

                        if (!context.mounted) return;

                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                              (route) => false,
                        );
                      },
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              );
            },
          );
        },
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
                selected: false,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveCamera(),
                    ),
                  );
                },
              ),
            ),

            Expanded(
              child: _navItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: true,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    bool showArrow = false,
  }) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          if (showArrow)
            const Icon(Icons.arrow_forward, color: Colors.grey),
        ],
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
