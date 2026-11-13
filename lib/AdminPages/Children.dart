
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ChildDetails.dart';

class Children extends StatelessWidget {
  const Children({super.key});

  static const Color purple = Color(0xFFAA6BD5);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('children')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: purple),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading children',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final children = snapshot.data?.docs ?? [];

        if (children.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.child_care,
                  size: 55,
                  color: Colors.grey,
                ),
                SizedBox(height: 10),
                Text(
                  'No children registered yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 25,
          ),
          child: GridView.builder(
            itemCount: children.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 22,
              crossAxisSpacing: 18,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final doc = children[index];
              final child = doc.data();

              final name = child['name']?.toString() ?? 'Unknown';
              final image = child['photoUrl']?.toString() ?? '';
              final status = child['status']?.toString() ?? 'Unknown';
              final nfcId = child['nfcId']?.toString() ?? 'Not connected';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildDetails(
                        name: name,
                        image: image,
                        status: status,
                        nfcId: nfcId,
                      ),
                    ),
                  );
                },
                child: _buildChildCard(
                  name: name,
                  image: image,
                  status: status,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChildCard({
    required String name,
    required String image,
    required String status,
  }) {
    final isAsleep = status.toLowerCase() == 'asleep';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 64,
          backgroundColor: const Color(0xFFE8C8F5),
          child: ClipOval(
            child: image.isEmpty
                ? const Icon(
              Icons.child_care,
              size: 55,
              color: purple,
            )
                : image.startsWith('assets/')
                ? Image.asset(
              image,
              width: 128,
              height: 128,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.child_care,
                  size: 55,
                  color: purple,
                );
              },
            )
                : Image.network(
              image,
              width: 128,
              height: 128,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.child_care,
                  size: 55,
                  color: purple,
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 5),

        Text(
          name,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.circle,
              size: 11,
              color: isAsleep
                  ? Colors.yellow.shade700
                  : Colors.green,
            ),
            const SizedBox(width: 5),
            Text(
              status,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
