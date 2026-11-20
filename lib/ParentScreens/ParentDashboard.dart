
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:senior2/StatusIcon/StatusIcons.dart';
import 'package:senior2/ParentScreens/SettingsPage.dart';
import 'package:senior2/ParentScreens/ParentProfile.dart';
import 'package:senior2/SharedCamera/LiveCamera.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  static const Color purple = Color(0xFF9B55D5);
  static const Color green = Color(0xFF00D83D);
  static const Color background = Color(0xFFF3F2F8);
  static const Color darkText = Color(0xFF292929);

  static final FirebaseDatabase realtimeDatabase =
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://kidsentinel-dd697-default-rtdb.firebaseio.com',
  );

  String calculateAge(Timestamp birthTimestamp) {
    final birthDate = birthTimestamp.toDate();
    final today = DateTime.now();

    int months = (today.year - birthDate.year) * 12 +
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
        body: Center(
          child: Text('Please log in again.'),
        ),
      );
    }

    debugPrint('========== PARENT DASHBOARD ==========');
    debugPrint('PARENT UID: ${user.uid}');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parents')
          .doc(user.uid)
          .snapshots(),
      builder: (context, parentSnapshot) {
        if (parentSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (parentSnapshot.hasError ||
            !parentSnapshot.hasData ||
            !parentSnapshot.data!.exists) {
          debugPrint(
            'PARENT FIRESTORE ERROR: ${parentSnapshot.error}',
          );

          return const Scaffold(
            body: Center(
              child: Text('Could not load parent information.'),
            ),
          );
        }

        final parentData =
        parentSnapshot.data!.data() as Map<String, dynamic>;

        final firstName = parentData['firstName'] ?? 'Parent';

        final childIds = List<String>.from(
          parentData['childIds'] ?? [],
        );

        if (childIds.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('No child linked to this account.'),
            ),
          );
        }

        final childId = childIds.first;

        debugPrint('CHILD ID: $childId');

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('children')
              .doc(childId)
              .snapshots(),
          builder: (context, childSnapshot) {
            if (childSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (childSnapshot.hasError ||
                !childSnapshot.hasData ||
                !childSnapshot.data!.exists) {
              debugPrint(
                'CHILD FIRESTORE ERROR: ${childSnapshot.error}',
              );

              return const Scaffold(
                body: Center(
                  child: Text('Could not load child information.'),
                ),
              );
            }

            final childData =
            childSnapshot.data!.data() as Map<String, dynamic>;

            final childName = childData['name'] ?? 'Child';

            final birthDateValue = childData['birthDate'];

            final Timestamp? birthTimestamp =
            birthDateValue is Timestamp
                ? birthDateValue
                : null;

            final age = birthTimestamp != null
                ? calculateAge(birthTimestamp)
                : 'Not available';

            final photoUrl = childData['photoUrl'] ?? '';

            return StreamBuilder<DatabaseEvent>(
              stream: realtimeDatabase
                  .ref('childStatus/$childId')
                  .onValue,
              builder: (context, statusSnapshot) {
                if (statusSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (statusSnapshot.hasError) {
                  debugPrint(
                    'RTDB ERROR: ${statusSnapshot.error}',
                  );
                }

                final rawData =
                    statusSnapshot.data?.snapshot.value;

                debugPrint('RTDB PATH: childStatus/$childId');
                debugPrint('RTDB RAW DATA: $rawData');
                debugPrint('RTDB DATA TYPE: ${rawData.runtimeType}');

                final Map<String, dynamic> liveData =
                rawData is Map
                    ? Map<String, dynamic>.from(rawData)
                    : {};

                // Check NFC connection first
                final nfcConnected =
                    liveData['nfcConnected'] == true;

                // Show child status only when NFC is connected
                final status = nfcConnected
                    ? (liveData['status']?.toString() ?? 'Unknown')
                    : 'Unknown';

                debugPrint('CHILD STATUS: $status');
                debugPrint('NFC CONNECTED: $nfcConnected');
                debugPrint('======================================');

                return _buildDashboard(
                  context: context,
                  firstName: firstName.toString(),
                  childName: childName.toString(),
                  age: age,
                  status: status,
                  photoUrl: photoUrl.toString(),
                  nfcConnected: nfcConnected,
                  childId: childId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard({
    required BuildContext context,
    required String firstName,
    required String childName,
    required String age,
    required String status,
    required String photoUrl,
    required bool nfcConnected,
    required String childId,
  }) {
    final isSleeping = status.toLowerCase().contains('sleep');

    final statusColor = isSleeping ? purple : green;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello, $firstName 👋',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.black,
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // Child Information Card
              _buildCard(
                child: Row(
                  children: [
                    Container(
                      width: 85,
                      height: 85,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8B5BB5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: photoUrl.isNotEmpty
                          ? Image.asset(
                        photoUrl,
                        width: 85,
                        height: 85,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) {
                          debugPrint('IMAGE ERROR: $error');

                          return const Center(
                            child: Text(
                              '👧🏻',
                              style: TextStyle(fontSize: 55),
                            ),
                          );
                        },
                      )
                          : const Center(
                        child: Text(
                          '👧🏻',
                          style: TextStyle(fontSize: 55),
                        ),
                      ),
                    ),

                    const SizedBox(width: 25),

                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            childName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            age,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // Child Status Card
              _buildCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    getStatusIcon(status),

                    const SizedBox(width: 20),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // NFC Status Card
              _buildCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'NFC Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            nfcConnected
                                ? 'Connected'
                                : 'Not Connected',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: nfcConnected
                                  ? green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        nfcConnected
                            ? Icons.check
                            : Icons.close,
                        color: nfcConnected ? green : Colors.red,
                        size: 38,
                      ),
                    ),

                    const SizedBox(width: 20),
                  ],
                ),
              ),

              const SizedBox(height: 35),
            ],
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
                selected: true,
                onTap: () {},
              ),
            ),
            Expanded(
              child: _navItem(
                icon: Icons.videocam_outlined,
                label: 'Camera',
                selected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveCamera(
                        childId: childId,
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _navItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: false,
                onTap: () {
                  Navigator.push(
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

  // Reusable Card
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
            Icon(icon, size: 24, color: purple),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: purple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
