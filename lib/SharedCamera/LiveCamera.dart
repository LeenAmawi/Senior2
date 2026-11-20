
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    debugPrint('========== LIVE CAMERA ==========');
    debugPrint('AUTH UID: $uid');
    debugPrint('CHILD ID: $childId');
    debugPrint('=================================');

    // Correct Firestore path:
    // children/{childId}
    final firestoreStream = FirebaseFirestore.instance
        .collection('children')
        .doc(childId)
        .snapshots();

    // Realtime Database path remains unchanged.
    final rtdbStream = FirebaseDatabase.instance
        .ref('childStatus/$childId')
        .onValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Camera'),
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

          final rawData = rtdbSnapshot.data?.snapshot.value;

          final Map<dynamic, dynamic> statusData =
          rawData is Map ? rawData : {};

          final bool cameraOnline =
              statusData['cameraOnline'] == true;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestoreStream,
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.hasError) {
                debugPrint(
                  'FIRESTORE ERROR: ${firestoreSnapshot.error}',
                );

                return const Center(
                  child: Text('Unable to load child information'),
                );
              }

              if (firestoreSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!firestoreSnapshot.hasData ||
                  !firestoreSnapshot.data!.exists) {
                debugPrint('CHILD DOCUMENT NOT FOUND');

                return const Center(
                  child: Text('Child information not found'),
                );
              }

              final childData =
                  firestoreSnapshot.data!.data() ?? {};

              debugPrint('FIRESTORE PATH: ${firestoreSnapshot.data!.reference.path}');
              debugPrint('CHILD DATA: $childData');

              final String liveStreamUrl =
                  childData['liveStreamUrl']?.toString() ?? '';

              final bool cameraEnabled =
                  childData['cameraEnabled'] == true;

              if (!cameraEnabled) {
                return const Center(
                  child: Text(
                    'Camera is disabled',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }

              if (!cameraOnline) {
                return const Center(
                  child: Text(
                    'Camera is offline',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }

              if (liveStreamUrl.isEmpty) {
                return const Center(
                  child: Text(
                    'Camera is online, but no stream URL is available',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
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
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera is online',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Stream URL:'),
                      SelectableText(liveStreamUrl),
                      const SizedBox(height: 16),
                      const Text(
                        'Video playback is not configured yet.',
                        textAlign: TextAlign.center,
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
