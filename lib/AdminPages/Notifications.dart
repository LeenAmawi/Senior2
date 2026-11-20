
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Notifications extends StatelessWidget {
  const Notifications({super.key});

  static const Color purple = Color(0xFFAA6BD5);

  // =========================
  // NORMALIZE EVENT TYPE
  // =========================

  String _normalizeType(String type) {
    switch (type.toLowerCase()) {
      case 'lowbattery':
      case 'low_battery':
      case 'low-battery':
        return 'lowBattery';
      default:
        return type.toLowerCase();
    }
  }

  // =========================
  // NOTIFICATION ICONS
  // =========================

  IconData _getIcon(String type) {
    switch (_normalizeType(type)) {
      case 'identified':
        return Icons.link;
      case 'sleeping':
        return Icons.nights_stay_outlined;
      case 'obstacle':
      case 'danger':
        return Icons.warning_amber_rounded;
      case 'lowBattery':
        return Icons.battery_2_bar;
      default:
        return Icons.notifications;
    }
  }

  // =========================
  // NOTIFICATION COLORS
  // =========================

  Color _getColor(String type) {
    switch (_normalizeType(type)) {
      case 'identified':
        return Colors.blue;
      case 'sleeping':
        return Colors.yellow;
      case 'obstacle':
      case 'danger':
      case 'lowBattery':
        return Colors.red;
      default:
        return purple;
    }
  }

  // =========================
  // FORMAT TIME
  // =========================

  String _formatTime(dynamic timestamp) {
    if (timestamp is! Timestamp) {
      return 'Just now';
    }

    final date = timestamp.toDate().toLocal();

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'Pm' : 'Am';

    return '$hour:$minute $period';
  }

  // =========================
  // GET CHILD NAME
  // =========================

  String _getChildName(
      Map<String, dynamic> data,
      Map<String, String> childNames,
      ) {
    final existingName = data['childName']?.toString();

    if (existingName != null && existingName.trim().isNotEmpty) {
      return existingName.trim();
    }

    final childId = data['childId']?.toString();

    if (childId != null && childId.isNotEmpty) {
      return childNames[childId] ?? '';
    }

    return '';
  }

  // =========================
  // SENSOR EVENT MESSAGE
  // =========================

  String _getSensorMessage(
      Map<String, dynamic> data,
      Map<String, String> childNames,
      ) {
    final type = _normalizeType(
      data['type']?.toString() ?? '',
    );

    final childName = _getChildName(data, childNames);

    String message;

    switch (type) {
      case 'identified':
        message = 'identified successfully';
        break;

      case 'sleeping':
        message = 'is sleeping';
        break;

      case 'obstacle':
      case 'danger':
        message = 'Obstacle detected';

        if (data['wheelLock'] == true) {
          message += '\nBrakes Activated';
        }
        break;

      case 'lowBattery':
        message = 'Low battery';
        break;

      default:
        final existingMessage = data['message']?.toString();

        if (existingMessage != null &&
            existingMessage.trim().isNotEmpty) {
          message = existingMessage.trim();
        } else {
          message = 'New sensor event detected';
        }
    }

    if (childName.isNotEmpty) {
      if (type == 'sleeping') {
        return '$childName $message';
      }

      return '$childName - $message';
    }

    return message;
  }

  // =========================
  // SORT NOTIFICATIONS
  // =========================

  void _sortNotifications(
      List<Map<String, dynamic>> notifications,
      ) {
    notifications.sort((a, b) {
      final timeA = a['data']['createdAt'];
      final timeB = b['data']['createdAt'];

      if (timeA is! Timestamp && timeB is! Timestamp) {
        return 0;
      }

      if (timeA is! Timestamp) return 1;
      if (timeB is! Timestamp) return -1;

      return timeB.compareTo(timeA);
    });
  }

  // =========================
  // BUILD NOTIFICATION CARD
  // =========================

  Widget _buildNotificationCard(
      Map<String, dynamic> notification,
      Map<String, String> childNames,
      ) {
    final data = notification['data'] as Map<String, dynamic>;

    final type = data['type']?.toString() ?? '';

    final message = notification['source'] == 'sensor'
        ? _getSensorMessage(data, childNames)
        : data['message']?.toString() ?? 'New notification';

    final timestamp = data['createdAt'] ?? data['timestamp'];
    final time = _formatTime(timestamp);

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Icon(
            _getIcon(type),
            color: _getColor(type),
            size: 23,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            time,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // BUILD NOTIFICATIONS LIST
  // =========================

  Widget _buildNotificationsList(
      List<Map<String, dynamic>> notifications,
      Map<String, String> childNames,
      ) {
    if (notifications.isEmpty) {
      return const Center(
        child: Text(
          'No notifications yet.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      );
    }

    _sortNotifications(notifications);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        return _buildNotificationCard(
          notifications[index],
          childNames,
        );
      },
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final admin = FirebaseAuth.instance.currentUser;

    if (admin == null) {
      return const Center(
        child: Text(
          'Please login first.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    final firestore = FirebaseFirestore.instance;

    final notificationsStream = firestore
        .collection('notifications')
        .where('adminId', isEqualTo: admin.uid)
        .snapshots();

    final sensorEventsStream = firestore
        .collection('sensorEvents')
        .snapshots();

    final hiddenStatesStream = firestore
        .collection('adminNotificationStates')
        .where('adminId', isEqualTo: admin.uid)
        .snapshots();

    final childrenStream = firestore
        .collection('children')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notificationsStream,
      builder: (context, notificationSnapshot) {
        if (notificationSnapshot.hasError) {
          return const Center(
            child: Text('Something went wrong while loading notifications.'),
          );
        }

        if (!notificationSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: purple),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sensorEventsStream,
          builder: (context, sensorSnapshot) {
            if (sensorSnapshot.hasError) {
              return const Center(
                child: Text('Unable to load sensor events.'),
              );
            }

            if (!sensorSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: purple),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: hiddenStatesStream,
              builder: (context, stateSnapshot) {
                if (stateSnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load notification settings.'),
                  );
                }

                if (!stateSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: purple),
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: childrenStream,
                  builder: (context, childrenSnapshot) {
                    if (childrenSnapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load children information.'),
                      );
                    }

                    if (!childrenSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: purple),
                      );
                    }

                    // Get child names using document IDs.
                    final childNames = <String, String>{};

                    for (final doc in childrenSnapshot.data!.docs) {
                      final childData = doc.data();

                      final name =
                          childData['name']?.toString() ??
                              childData['childName']?.toString() ??
                              childData['fullName']?.toString();

                      if (name != null && name.trim().isNotEmpty) {
                        childNames[doc.id] = name.trim();
                      }
                    }

                    // Get hidden event IDs for this admin.
                    final hiddenEventIds = <String>{};

                    for (final doc in stateSnapshot.data!.docs) {
                      final data = doc.data();

                      if (data['hidden'] == true) {
                        final eventId = data['eventId']?.toString();

                        if (eventId != null && eventId.isNotEmpty) {
                          hiddenEventIds.add(eventId);
                        }
                      }
                    }

                    final allNotifications =
                    <Map<String, dynamic>>[];

                    // Add old notifications.
                    for (final doc
                    in notificationSnapshot.data!.docs) {
                      allNotifications.add({
                        'id': doc.id,
                        'source': 'notification',
                        'data': doc.data(),
                      });
                    }

                    // Add visible sensor events.
                    for (final doc in sensorSnapshot.data!.docs) {
                      if (hiddenEventIds.contains(doc.id)) {
                        continue;
                      }

                      allNotifications.add({
                        'id': doc.id,
                        'source': 'sensor',
                        'data': doc.data(),
                      });
                    }

                    return _buildNotificationsList(
                      allNotifications,
                      childNames,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
