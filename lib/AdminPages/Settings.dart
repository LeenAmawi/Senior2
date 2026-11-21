
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const Color purple = Color(0xFFAA6BD5);

  final CollectionReference<Map<String, dynamic>> childrenCollection =
  FirebaseFirestore.instance.collection('children');

  final CollectionReference<Map<String, dynamic>> codesCollection =
  FirebaseFirestore.instance.collection('connectionCodes');

  final CollectionReference<Map<String, dynamic>> adminCodesCollection =
  FirebaseFirestore.instance.collection('adminCodes');

  final CollectionReference<Map<String, dynamic>> parentsCollection =
  FirebaseFirestore.instance.collection('parents');

  final CollectionReference<Map<String, dynamic>> sensorEventsCollection =
  FirebaseFirestore.instance.collection('sensorEvents');

  final FirebaseDatabase realtimeDatabase = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://kidsentinel-dd697-default-rtdb.firebaseio.com',
  );

  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;

  // ==========================================
  // REALTIME DATABASE - INITIAL CHILD STATUS
  // ==========================================

  Future<void> _initializeChildStatus(String childId) async {
    await realtimeDatabase.ref('childStatus/$childId').set({
      'deviceOnline': false,
      'status': 'Unknown',
      'batteryLevel': 0,
      'obstacleDetected': false,
      'wheelLock': false,
      'nfcConnected': false,
      'cameraOnline': false,
      'identified': false,
    });
  }

  // ==========================================
  // HELPERS
  // ==========================================

  String _generateCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(
      12,
          (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  String _calculateAge(DateTime birthDate) {
    final today = DateTime.now();

    int years = today.year - birthDate.year;
    int months = today.month - birthDate.month;

    if (today.day < birthDate.day) {
      months--;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years < 0) return 'Not specified';
    if (years == 0 && months == 0) return 'Less than a month';
    if (years == 0) return '$months months';
    if (months == 0) return '$years years';

    return '$years years, $months months';
  }

  DateTime? _getBirthDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // ==========================================
  // IMAGE PICKER AND STORAGE
  // ==========================================

  Future<File?> _pickChildPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e, stackTrace) {
      debugPrint('IMAGE PICKER ERROR: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open gallery: $e')),
        );
      }

      return null;
    }
  }

  Future<String> _uploadChildPhoto(
      File image,
      String childId,
      ) async {
    final reference = FirebaseStorage.instance
        .ref()
        .child('children')
        .child(childId)
        .child('profile.jpg');

    final uploadTask = await reference.putFile(image);

    return await uploadTask.ref.getDownloadURL();
  }

  // ==========================================
  // DELETE FIRESTORE DOCUMENTS IN BATCHES
  // ==========================================

  Future<void> _deleteFirestoreDocuments(
      List<DocumentReference<Map<String, dynamic>>> references,
      ) async {
    final uniqueReferences =
    <String, DocumentReference<Map<String, dynamic>>>{};

    for (final reference in references) {
      uniqueReferences[reference.path] = reference;
    }

    final docs = uniqueReferences.values.toList();

    for (int i = 0; i < docs.length; i += 450) {
      final batch = FirebaseFirestore.instance.batch();

      final end = (i + 450 < docs.length) ? i + 450 : docs.length;

      for (int j = i; j < end; j++) {
        batch.delete(docs[j]);
      }

      await batch.commit();
    }
  }

  // ==========================================
  // CREATE ADMIN INVITATION
  // ==========================================

  Future<void> _createAdminInvite() async {
    if (_isSaving) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin is not signed in.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final code = _generateCode();

    final expiryDate = DateTime.now().add(
      const Duration(days: 3650),
    );

    final firestoreRef = adminCodesCollection.doc(code);
    final realtimeRef = realtimeDatabase.ref('adminInvites/$code');

    try {
      await firestoreRef.set({
        'isUsed': false,
        'usedBy': null,
        'expiresAt': Timestamp.fromDate(expiryDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await realtimeRef.set({
          'createdBy': currentUser.uid,
          'expiresAt': expiryDate.millisecondsSinceEpoch,
        });
      } catch (e) {
        try {
          await firestoreRef.delete();
        } catch (rollbackError) {
          debugPrint('ADMIN INVITE ROLLBACK ERROR: $rollbackError');
        }

        rethrow;
      }

      if (!mounted) return;

      _showInvitationDialog(
        title: 'Admin Invitation Created',
        message: 'Give this code to the new administrator:',
        code: code,
      );
    } catch (e) {
      debugPrint('ADMIN INVITE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create admin invitation: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ==========================================
  // INVITATION DIALOG
  // ==========================================

  void _showInvitationDialog({
    required String title,
    required String message,
    required String code,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: purple,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F2F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: purple,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This code can be used once.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: code),
                );

                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Invitation code copied'),
                  ),
                );
              },
              icon: const Icon(Icons.copy, color: purple),
              label: const Text(
                'Copy',
                style: TextStyle(color: purple),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // ADD / EDIT CHILD DIALOG
  // ==========================================

  void _showChildDialog({
    String? childId,
    String? childName,
    DateTime? childBirthDate,
    String? childPhotoUrl,
  }) {
    String enteredChildName = childName ?? '';
    DateTime? selectedBirthDate = childBirthDate;
    File? selectedImage;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                childId == null ? 'Adding New Child' : 'Edit Child',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: purple,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: enteredChildName,
                      onChanged: (value) {
                        enteredChildName = value;
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter child name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: purple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Birth Date',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 7),
                    InkWell(
                      onTap: saving
                          ? null
                          : () async {
                        final pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate:
                          selectedBirthDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: purple,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null &&
                            dialogContext.mounted) {
                          setDialogState(() {
                            selectedBirthDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: purple,
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedBirthDate == null
                                    ? 'Select birth date'
                                    : '${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}',
                                style: TextStyle(
                                  color: selectedBirthDate == null
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Child Photo',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFFE8C8F5),
                            backgroundImage: selectedImage != null
                                ? FileImage(selectedImage!)
                                : (childPhotoUrl != null &&
                                childPhotoUrl.startsWith('http')
                                ? NetworkImage(childPhotoUrl)
                                : null),
                            child: selectedImage == null &&
                                (childPhotoUrl == null ||
                                    !childPhotoUrl.startsWith('http'))
                                ? const Icon(
                              Icons.person,
                              size: 38,
                              color: purple,
                            )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                              final image = await _pickChildPhoto();

                              if (image != null &&
                                  dialogContext.mounted) {
                                setDialogState(() {
                                  selectedImage = image;
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              color: purple,
                            ),
                            label: const Text(
                              'Choose Photo',
                              style: TextStyle(color: purple),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    final name = enteredChildName.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter child name'),
                        ),
                      );
                      return;
                    }

                    if (selectedBirthDate == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please select birth date'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    if (mounted) {
                      setState(() {
                        _isSaving = true;
                      });
                    }

                    String? generatedCode;

                    try {
                      final age =
                      _calculateAge(selectedBirthDate!);

                      // ==================================
                      // ADD NEW CHILD
                      // ==================================

                      if (childId == null) {
                        final currentUser =
                            FirebaseAuth.instance.currentUser;

                        if (currentUser == null) {
                          throw Exception(
                            'Admin is not signed in.',
                          );
                        }

                        final childRef = childrenCollection.doc();
                        final code = _generateCode();
                        final codeRef = codesCollection.doc(code);

                        String photoUrl = '';

                        if (selectedImage != null) {
                          photoUrl = await _uploadChildPhoto(
                            selectedImage!,
                            childRef.id,
                          );
                        }

                        final expiryDate = DateTime.now().add(
                          const Duration(days: 3650),
                        );

                        // Firestore stores permanent child information
                        // and the camera permission setting.
                        final batch =
                        FirebaseFirestore.instance.batch();

                        batch.set(childRef, {
                          'name': name,
                          'birthDate': Timestamp.fromDate(
                            selectedBirthDate!,
                          ),
                          'age': age,
                          'photoUrl': photoUrl,

                          // Camera permission setting:
                          // Enabled by default.
                          'cameraEnabled': true,

                          'connectionCodeId': code,
                          'parentIds': [],
                          'createdAt':
                          FieldValue.serverTimestamp(),
                        });

                        batch.set(codeRef, {
                          'childId': childRef.id,
                          'isUsed': false,
                          'usedBy': null,
                          'expiresAt':
                          Timestamp.fromDate(expiryDate),
                          'createdAt':
                          FieldValue.serverTimestamp(),
                        });

                        await batch.commit();

                        // Realtime Database stores live device status.
                        try {
                          await _initializeChildStatus(childRef.id);

                          await realtimeDatabase
                              .ref('parentInvites/$code')
                              .set({
                            'childId': childRef.id,
                            'createdBy': currentUser.uid,
                            'expiresAt':
                            expiryDate.millisecondsSinceEpoch,
                          });
                        } catch (rtdbError) {
                          debugPrint(
                            'RTDB initialization error: $rtdbError',
                          );

                          // Roll back the created records if RTDB fails.
                          try {
                            await realtimeDatabase
                                .ref('childStatus/${childRef.id}')
                                .remove();

                            await realtimeDatabase
                                .ref('parentInvites/$code')
                                .remove();
                          } catch (rollbackError) {
                            debugPrint(
                              'RTDB rollback error: $rollbackError',
                            );
                          }

                          try {
                            await childRef.delete();
                            await codeRef.delete();
                          } catch (rollbackError) {
                            debugPrint(
                              'Firestore rollback error: $rollbackError',
                            );
                          }

                          if (photoUrl.isNotEmpty) {
                            try {
                              await FirebaseStorage.instance
                                  .ref()
                                  .child('children')
                                  .child(childRef.id)
                                  .child('profile.jpg')
                                  .delete();
                            } catch (_) {}
                          }

                          rethrow;
                        }

                        generatedCode = code;
                      }

                      // ==================================
                      // EDIT EXISTING CHILD
                      // ==================================

                      else {
                        final Map<String, dynamic> updates = {
                          'name': name,
                          'birthDate': Timestamp.fromDate(
                            selectedBirthDate!,
                          ),
                          'age': age,
                        };

                        if (selectedImage != null) {
                          final photoUrl = await _uploadChildPhoto(
                            selectedImage!,
                            childId,
                          );

                          updates['photoUrl'] = photoUrl;
                        }

                        await childrenCollection
                            .doc(childId)
                            .update(updates);
                      }

                      if (!mounted || !dialogContext.mounted) {
                        return;
                      }

                      setState(() {
                        _isSaving = false;
                      });

                      Navigator.of(dialogContext).pop();

                      if (generatedCode != null) {
                        WidgetsBinding.instance.addPostFrameCallback(
                              (_) {
                            if (mounted) {
                              _showCodeDialog(generatedCode!);
                            }
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Child updated successfully',
                            ),
                          ),
                        );
                      }
                    } on FirebaseException catch (e) {
                      debugPrint(
                        'Firebase error: ${e.code} - ${e.message}',
                      );

                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Firebase error: ${e.message ?? e.code}',
                            ),
                          ),
                        );
                      }
                    } catch (e, stackTrace) {
                      debugPrint('Save error: $e');
                      debugPrint('$stackTrace');

                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSaving = false;
                        });
                      }

                      if (dialogContext.mounted) {
                        setDialogState(() {
                          saving = false;
                        });
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(childId == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // CHILD CONNECTION CODE DIALOG
  // ==========================================

  void _showCodeDialog(String code) {
    _showInvitationDialog(
      title: 'Child Added Successfully',
      message: 'Give this connection code to the parent:',
      code: code,
    );
  }

  // ==========================================
  // FIND LINKED PARENTS
  // ==========================================

  Future<Set<String>> _getLinkedParentIds(
      String childId,
      Map<String, dynamic> child,
      ) async {
    final Set<String> parentIds = {};

    final storedParentIds = child['parentIds'];

    if (storedParentIds is List) {
      for (final id in storedParentIds) {
        if (id != null && id.toString().trim().isNotEmpty) {
          parentIds.add(id.toString());
        }
      }
    }

    // Check parent link in Realtime Database.
    try {
      final linkSnapshot = await realtimeDatabase
          .ref('childStatus/$childId/parentLink')
          .get();

      if (linkSnapshot.exists && linkSnapshot.value is Map) {
        final link = Map<dynamic, dynamic>.from(
          linkSnapshot.value as Map,
        );

        final uid = link['uid'];

        if (uid != null && uid.toString().trim().isNotEmpty) {
          parentIds.add(uid.toString());
        }
      }
    } catch (e) {
      debugPrint('Could not read RTDB parent link: $e');
    }

    // Check parent documents containing this child ID.
    try {
      final parentSnapshot = await parentsCollection
          .where('childIds', arrayContains: childId)
          .get();

      for (final doc in parentSnapshot.docs) {
        parentIds.add(doc.id);
      }
    } catch (e) {
      debugPrint('Could not query parent documents: $e');
    }

    return parentIds;
  }

  // ==========================================
  // DELETE CHILD
  // ==========================================

  Future<void> _deleteChild(
      String childId,
      Map<String, dynamic> child,
      ) async {
    if (_isSaving) return;

    final parentIds = await _getLinkedParentIds(childId, child);

    if (!mounted) return;

    final isLinked = parentIds.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isLinked
                ? 'Delete Child and Parent Account'
                : 'Delete Child',
          ),
          content: Text(
            isLinked
                ? 'This child is connected to a parent account. '
                'Are you sure you want to delete the child and its '
                'linked parent data? The parent Authentication account '
                'will not be deleted.'
                : 'Are you sure you want to delete this child?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final List<DocumentReference<Map<String, dynamic>>>
      deleteReferences = [];

      // Delete child document.
      deleteReferences.add(childrenCollection.doc(childId));

      // Collect all connection codes belonging to this child.
      final codeIds = <String>{};

      final savedCodeId = child['connectionCodeId'];

      if (savedCodeId != null &&
          savedCodeId.toString().trim().isNotEmpty) {
        codeIds.add(savedCodeId.toString());
      }

      final codesSnapshot = await codesCollection
          .where('childId', isEqualTo: childId)
          .get();

      for (final doc in codesSnapshot.docs) {
        codeIds.add(doc.id);
      }

      for (final codeId in codeIds) {
        deleteReferences.add(codesCollection.doc(codeId));
      }

      // Collect sensor events belonging to this child.
      final eventsSnapshot = await sensorEventsCollection
          .where('childId', isEqualTo: childId)
          .get();

      for (final doc in eventsSnapshot.docs) {
        deleteReferences.add(doc.reference);
      }

      // Handle linked parent documents.
      for (final parentId in parentIds) {
        final parentRef = parentsCollection.doc(parentId);
        final parentSnapshot = await parentRef.get();

        if (!parentSnapshot.exists) continue;

        final parentData = parentSnapshot.data() ?? {};
        final dynamic childIdsValue = parentData['childIds'];

        final List<String> otherChildIds = [];

        if (childIdsValue is List) {
          for (final id in childIdsValue) {
            if (id != null && id.toString() != childId) {
              otherChildIds.add(id.toString());
            }
          }
        }

        if (otherChildIds.isEmpty) {
          // Delete parent Firestore document if no other children exist.
          deleteReferences.add(parentRef);
        } else {
          // Keep parent and remove only this child.
          await parentRef.update({
            'childIds': FieldValue.arrayRemove([childId]),
          });
        }
      }

      // Delete Firestore documents.
      await _deleteFirestoreDocuments(deleteReferences);

      // Delete child's Realtime Database status and parent link.
      await realtimeDatabase
          .ref('childStatus/$childId')
          .remove();

      // Delete parent invitation entries for this child's codes.
      for (final codeId in codeIds) {
        await realtimeDatabase
            .ref('parentInvites/$codeId')
            .remove();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLinked
                ? 'Child and linked parent data deleted successfully'
                : 'Child deleted successfully',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'DELETE FIREBASE ERROR: ${e.code} - ${e.message}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase error: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('DELETE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting child: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==========================================
  // ABOUT
  // ==========================================

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'KidSentinel',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Smart Child Monitoring System',
    );
  }

  // ==========================================
  // LOGOUT
  // ==========================================

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log out: $e')),
      );
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 25, 18, 20),
      child: Column(
        children: [
          const SizedBox(height: 5),

          const Text(
            'Managing the Children',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _showChildDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Adding New Child  +',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _createAdminInvite,
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Create Admin Invitation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: purple,
                side: const BorderSide(color: purple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 13),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: childrenCollection.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Error loading children'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: purple),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No children added yet'),
                );
              }

              return Column(
                children: List.generate(docs.length, (index) {
                  final doc = docs[index];
                  final child = doc.data();

                  final photoUrl =
                      child['photoUrl'] as String? ?? '';

                  ImageProvider? photoProvider;

                  if (photoUrl.startsWith('http')) {
                    photoProvider = NetworkImage(photoUrl);
                  } else if (photoUrl.startsWith('assets/')) {
                    photoProvider = AssetImage(photoUrl);
                  }

                  return Container(
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE8C8F5),
                          backgroundImage: photoProvider,
                          child: photoProvider == null
                              ? Text(
                            child['avatar'] ?? '🧒',
                            style: const TextStyle(fontSize: 18),
                          )
                              : null,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            child['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                            _showChildDialog(
                              childId: doc.id,
                              childName: child['name'] ?? '',
                              childBirthDate: _getBirthDate(
                                child['birthDate'],
                              ),
                              childPhotoUrl: photoUrl,
                            );
                          },
                          icon: const Icon(
                            Icons.edit,
                            color: purple,
                            size: 20,
                          ),
                        ),

                        IconButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                            _deleteChild(doc.id, child);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),

          const SizedBox(height: 30),

          GestureDetector(
            onTap: _showAboutDialog,
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: purple),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'About KidSentinel',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log out',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
