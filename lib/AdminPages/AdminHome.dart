
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:senior2/firebase_database_service.dart';

import 'Children.dart';
import 'ChildDetails.dart';
import 'Notifications.dart';
import 'Settings.dart' as admin_settings;

class AdminHome extends StatefulWidget {
  final int initialIndex;

  const AdminHome({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  static const Color purple = Color(0xFFAA6BD5);
  static const Color background = Color(0xFFF3F2F8);

  late int selectedIndex;

  final List<String> pageTitles = [
    'Home',
    'Children',
    'Notifications',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex.clamp(0, 3);
  }

  // =========================
  // DELETE ALL NOTIFICATIONS
  // =========================

  Future<void> _deleteAllNotifications() async {
    final admin = FirebaseAuth.instance.currentUser;

    if (admin == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Notifications'),
          content: const Text(
            'Are you sure you want to delete all notifications?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final oldNotifications = await firestore
          .collection('notifications')
          .where('adminId', isEqualTo: admin.uid)
          .get();

      final sensorEvents = await firestore
          .collection('sensorEvents')
          .get();

      final existingStates = await firestore
          .collection('adminNotificationStates')
          .where('adminId', isEqualTo: admin.uid)
          .get();

      final hiddenEventIds = existingStates.docs
          .map((doc) => doc.data()['eventId']?.toString())
          .whereType<String>()
          .toSet();

      for (int i = 0; i < oldNotifications.docs.length; i += 450) {
        final batch = firestore.batch();

        final end = (i + 450 < oldNotifications.docs.length)
            ? i + 450
            : oldNotifications.docs.length;

        for (int j = i; j < end; j++) {
          batch.delete(oldNotifications.docs[j].reference);
        }

        await batch.commit();
      }

      final eventsToHide = sensorEvents.docs
          .where((event) => !hiddenEventIds.contains(event.id))
          .toList();

      for (int i = 0; i < eventsToHide.length; i += 450) {
        final batch = firestore.batch();

        final end = (i + 450 < eventsToHide.length)
            ? i + 450
            : eventsToHide.length;

        for (int j = i; j < end; j++) {
          final event = eventsToHide[j];

          final stateRef = firestore
              .collection('adminNotificationStates')
              .doc('${admin.uid}_${event.id}');

          batch.set(stateRef, {
            'adminId': admin.uid,
            'eventId': event.id,
            'hidden': true,
            'hiddenAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications deleted successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete notifications: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildSelectedPage()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSelectedPage() {
    switch (selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const Children();
      case 2:
        return const Notifications();
      case 3:
        return const admin_settings.Settings();
      default:
        return _buildHomeContent();
    }
  }

  // =========================
  // HEADER
  // =========================

  Widget _buildHeader() {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: purple,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          if (selectedIndex != 0)
            IconButton(
              onPressed: () {
                setState(() {
                  selectedIndex = 0;
                });
              },
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
            )
          else
            const SizedBox(width: 48),

          Expanded(
            child: Center(
              child: Text(
                pageTitles[selectedIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (selectedIndex == 0)
            IconButton(
              onPressed: () {
                setState(() {
                  selectedIndex = 3;
                });
              },
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 21,
              ),
            )
          else if (selectedIndex == 2)
            IconButton(
              onPressed: _deleteAllNotifications,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.black,
                size: 25,
              ),
              tooltip: 'Delete all notifications',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // =========================
  // HOME CONTENT
  // =========================

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
      child: Column(
        children: [
          _buildLastNotification(),
          const SizedBox(height: 25),
          _buildStatusCards(),
          const SizedBox(height: 25),
          _buildChildrenSection(),
        ],
      ),
    );
  }

  // =========================
  // STATUS CARDS - REALTIME DATABASE
  // COUNT IDENTIFIED CHILDREN ONLY
  // =========================

  Widget _buildStatusCards() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabaseService.database
          .ref('childStatus')
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red,
                  title: 'Alerts: --',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  icon: Icons.battery_2_bar,
                  color: Colors.red,
                  title: 'Low Battery: --',
                ),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: purple),
          );
        }

        int alertsCount = 0;
        int lowBatteryCount = 0;

        final childStatuses = snapshot.data!.snapshot.value;

        if (childStatuses is Map) {
          for (final childStatus in childStatuses.values) {
            if (childStatus is! Map) continue;

            // Ignore children who are not identified.
            if (childStatus['identified'] != true) continue;

            if (childStatus['obstacleDetected'] == true) {
              alertsCount++;
            }

            final battery = childStatus['batteryLevel'];

            if (battery is num && battery > 0 && battery <= 20) {
              lowBatteryCount++;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
                title: 'Alerts: $alertsCount',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.battery_2_bar,
                color: Colors.red,
                title: 'Low Battery: $lowBatteryCount',
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // CHILDREN SECTION
  // SHOW ONLY 4 CHILDREN ON HOME
  // =========================

  Widget _buildChildrenSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Children',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedIndex = 1;
                  });
                },
                child: const Text(
                  'See all →',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('children')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: purple),
                );
              }

              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'Error loading children',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                );
              }

              final children = snapshot.data?.docs ?? [];

              if (children.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.child_care,
                        size: 45,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No children registered yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final displayedChildren = children.take(4).toList();

              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total Children: ${children.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: displayedChildren.map((doc) {
                      final data = doc.data();

                      return SizedBox(
                        width: 125,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildDetails(
                                  childId: doc.id,
                                ),
                              ),
                            );
                          },
                          child: _buildLiveChildCard(
                            childId: doc.id,
                            name: data['name']?.toString() ?? 'Unknown',
                            image: data['photoUrl']?.toString() ?? '',
                            firestoreStatus:
                            data['status']?.toString() ?? 'Unknown',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // =========================
  // CHILD LIVE STATUS - REALTIME DATABASE
  // SHOW STATUS ONLY WHEN IDENTIFIED
  // =========================

  Widget _buildLiveChildCard({
    required String childId,
    required String name,
    required String image,
    required String firestoreStatus,
  }) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabaseService.database
          .ref('childStatus/$childId')
          .onValue,
      builder: (context, snapshot) {
        String status = '-';

        if (snapshot.hasData && !snapshot.hasError) {
          final value = snapshot.data!.snapshot.value;

          if (value is Map) {
            final identified = value['identified'] == true;

            if (identified) {
              status = value['status']?.toString() ?? '-';
            }
          }
        }

        return _buildChildCard(
          name: name,
          image: image,
          status: status,
        );
      },
    );
  }

  // =========================
  // LAST NOTIFICATION - FIRESTORE
  // =========================

  Widget _buildLastNotification() {
    final admin = FirebaseAuth.instance.currentUser;

    if (admin == null) {
      return _lastNotificationCard('Please login first', '');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('adminId', isEqualTo: admin.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _lastNotificationCard(
            'Could not load notifications',
            '',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _lastNotificationCard(
            'Notifications will appear here',
            '',
          );
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
          final timeA = a.data()['createdAt'];
          final timeB = b.data()['createdAt'];

          if (timeA is! Timestamp) return 1;
          if (timeB is! Timestamp) return -1;

          return timeB.compareTo(timeA);
        });

        final data = docs.first.data();

        final message = data['message']?.toString() ?? '';
        final createdAt = data['createdAt'];

        String timeText = '';

        if (createdAt is Timestamp) {
          final dateTime = createdAt.toDate().toLocal();
          final hour = dateTime.hour.toString().padLeft(2, '0');
          final minute = dateTime.minute.toString().padLeft(2, '0');

          timeText = '$hour:$minute';
        }

        return _lastNotificationCard(
          message.isEmpty ? 'No message' : message,
          timeText,
        );
      },
    );
  }

  Widget _lastNotificationCard(String message, String time) {
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none,
            color: Color(0xFFB5C900),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last notification',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================
  // STATUS CARD
  // =========================

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return Container(
      height: 140,
      decoration: _cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 47),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // CHILD CARD
  // =========================

  Widget _buildChildCard({
    required String name,
    required String image,
    required String status,
  }) {
    final lowerStatus = status.toLowerCase();

    final Color statusColor = status == '-'
        ? Colors.grey
        : lowerStatus == 'awake'
        ? Colors.green
        : lowerStatus == 'sleeping' || lowerStatus == 'asleep'
        ? Colors.orange
        : Colors.grey;

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE8C8F5),
            child: ClipOval(
              child: image.isEmpty
                  ? const Icon(
                Icons.child_care,
                size: 38,
                color: purple,
              )
                  : image.startsWith('assets/')
                  ? Image.asset(
                image,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.child_care,
                    size: 38,
                    color: purple,
                  );
                },
              )
                  : Image.network(
                image,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.child_care,
                    size: 38,
                    color: purple,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.circle,
                color: statusColor,
                size: 10,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // BOTTOM NAVIGATION
  // =========================

  Widget _buildBottomNavigation() {
    final items = [
      Icons.home_outlined,
      Icons.people_outline,
      Icons.notifications_none,
      Icons.settings_outlined,
    ];

    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final isSelected = selectedIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF0E1F8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index],
                        color: purple,
                        size: 21,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pageTitles[index],
                        style: const TextStyle(
                          color: purple,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // =========================
  // CARD DECORATION
  // =========================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 4,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
