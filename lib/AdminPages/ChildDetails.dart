
import 'package:flutter/material.dart';

import 'AdminHome.dart';

class ChildDetails extends StatelessWidget {
  final String name;
  final String image;
  final String status;
  final String nfcId;
  final String presence;
  final String identification;
  final String wheelLock;

  const ChildDetails({
    super.key,
    required this.name,
    required this.image,
    required this.status,
    required this.nfcId,
    this.presence = 'Unknown',
    this.identification = 'Unknown',
    this.wheelLock = 'Unknown',
  });

  static const Color purple = Color(0xFFAA6BD5);
  static const Color background = Color(0xFFF3F2F8);

  Widget _buildChildImage() {
    if (image.isEmpty) {
      return const Icon(
        Icons.child_care,
        size: 60,
        color: purple,
      );
    }

    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        width: 130,
        height: 130,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.child_care,
            size: 60,
            color: purple,
          );
        },
      );
    }

    return Image.network(
      image,
      width: 130,
      height: 130,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.child_care,
          size: 60,
          color: purple,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        CircleAvatar(
                          radius: 65,
                          backgroundColor: const Color(0xFFE8C8F5),
                          child: ClipOval(
                            child: _buildChildImage(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    _buildInfoCard('Status', status),
                    _buildInfoCard('Presence', presence),
                    _buildInfoCard('Identification', identification),
                    _buildInfoCard('Wheel lock', wheelLock),

                    _buildInfoCard(
                      'NFC ID',
                      nfcId.isEmpty || nfcId == 'null'
                          ? 'Not connected'
                          : nfcId,
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Live camera is not connected yet',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Live camera',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      color: purple,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Child Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      height: 40,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),

          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final items = [
      Icons.home_outlined,
      Icons.person_outline,
      Icons.notifications_none,
      Icons.settings_outlined,
    ];

    final titles = [
      'Home',
      'Children',
      'Notifications',
      'Settings',
    ];

    return Container(
      height: 50,
      color: Colors.white,
      child: Row(
        children: List.generate(items.length, (index) {
          final selected = index == 1;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminHome(
                      initialIndex: index,
                    ),
                  ),
                      (route) => false,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected
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
                      size: 19,
                    ),
                    Text(
                      titles[index],
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
    );
  }
}
