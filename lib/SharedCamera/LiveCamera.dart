
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveCamera extends StatelessWidget {
  final String childId;
  final String kindergartenId;

  const LiveCamera({
    super.key,
    required this.childId,
    this.kindergartenId = '8Q7bnU6zLpENqM4XseTO',
  });

  static const Color purple = Color(0xFFAA6BD5);
  static const Color background = Color(0xFFF3F2F8);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    debugPrint('========== LIVE CAMERA ==========');
    debugPrint('AUTH UID: $uid');
    debugPrint('CHILD ID: $childId');
    debugPrint('=================================');

    final firestoreStream = FirebaseFirestore.instance
        .collection('children')
        .doc(childId)
        .snapshots();

    final rtdbStream = FirebaseDatabase.instance
        .ref('childStatus/$childId')
        .onValue;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Live Camera',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: rtdbStream,
        builder: (context, rtdbSnapshot) {
          if (rtdbSnapshot.hasError) {
            debugPrint('RTDB ERROR: ${rtdbSnapshot.error}');

            return const Center(
              child: Text('Error loading camera status'),
            );
          }

          if (rtdbSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: purple,
              ),
            );
          }

          final rawData = rtdbSnapshot.data?.snapshot.value;

          final Map<dynamic, dynamic> statusData =
          rawData is Map ? rawData : {};

          // Check if the child is identified
          final bool identified =
              statusData['identified'] == true;

          if (!identified) {
            return const Center(
              child: Text(
                'Child is not identified',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final bool cameraOnline =
              statusData['cameraOnline'] == true;

          return StreamBuilder<
              DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestoreStream,
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.hasError) {
                debugPrint(
                  'FIRESTORE ERROR: ${firestoreSnapshot.error}',
                );

                return const Center(
                  child: Text(
                    'Unable to load child information',
                  ),
                );
              }

              if (firestoreSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: purple,
                  ),
                );
              }

              if (!firestoreSnapshot.hasData ||
                  !firestoreSnapshot.data!.exists) {
                debugPrint('CHILD DOCUMENT NOT FOUND');

                return const Center(
                  child: Text(
                    'Child information not found',
                  ),
                );
              }

              final childData =
                  firestoreSnapshot.data!.data() ?? {};

              debugPrint(
                'FIRESTORE PATH: '
                    '${firestoreSnapshot.data!.reference.path}',
              );
              debugPrint('CHILD DATA: $childData');

              final String liveStreamUrl =
                  childData['liveStreamUrl']?.toString() ?? '';

              final bool cameraEnabled =
                  childData['cameraEnabled'] == true;

              if (!cameraEnabled) {
                return const Center(
                  child: Text(
                    'Camera is disabled',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                );
              }

              if (!cameraOnline) {
                return const Center(
                  child: Text(
                    'Camera is offline',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                );
              }

              if (liveStreamUrl.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Camera is online, but no stream URL is available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                );
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam,
                        size: 70,
                        color: purple,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera is online',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Stream URL:',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        liveStreamUrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Video playback is not configured yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
