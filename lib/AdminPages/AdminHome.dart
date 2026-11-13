
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Settings;

import 'Children.dart';
import 'Notifications.dart';
import 'Settings.dart';

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
        return const Settings();
      default:
        return _buildHomeContent();
    }
  }

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
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
      child: Column(
        children: [
          _buildLastNotification(),
          const SizedBox(height: 25),

          Row(
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
          ),

          const SizedBox(height: 25),
          _buildChildrenSection(),
        ],
      ),
    );
  }

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
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
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
                    children: children.map((doc) {
                      final data = doc.data();

                      return SizedBox(
                        width: 125,
                        child: _buildChildCard(
                          name: data['name']?.toString() ?? 'Unknown',
                          image: data['photoUrl']?.toString() ?? '',
                          status: data['status']?.toString() ?? 'Unknown',
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

  Widget _buildLastNotification() {
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: const Row(
        children: [
          Icon(
            Icons.notifications_none,
            color: Color(0xFFB5C900),
            size: 38,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last notification',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Notifications will appear here',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildChildCard({
    required String name,
    required String image,
    required String status,
  }) {
    final bool isAwake = status.toLowerCase() == 'awake';

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
                color: isAwake ? Colors.green : Colors.orange,
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
