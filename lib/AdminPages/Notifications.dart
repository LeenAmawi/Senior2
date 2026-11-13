
import 'package:flutter/material.dart';

class Notifications extends StatelessWidget {
  const Notifications({super.key});

  static const Color purple = Color(0xFFAA6BD5);

  final List<Map<String, dynamic>> notifications = const [
    {
      'icon': Icons.link,
      'color': Colors.blue,
      'message': 'John identified successfully',
      'time': '10:30 Am',
    },
    {
      'icon': Icons.nights_stay_outlined,
      'color': Colors.yellow,
      'message': 'Layla is sleeping',
      'time': '10:14 Am',
    },
    {
      'icon': Icons.warning_amber_rounded,
      'color': Colors.red,
      'message': 'Noah - Obstacle detected\nBreaks Activated',
      'time': '9:23 Am',
    },
    {
      'icon': Icons.link,
      'color': Colors.blue,
      'message': 'Liam identified successfully',
      'time': '8:17 Am',
    },
    {
      'icon': Icons.battery_2_bar,
      'color': Colors.red,
      'message': 'Daniel - Low battery',
      'time': '7:06 Am',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final notification = notifications[index];

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
                notification['icon'],
                color: notification['color'],
                size: 23,
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Text(
                  notification['message'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(width: 5),

              Text(
                notification['time'],
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
