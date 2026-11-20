
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

  final FirebaseDatabase realtimeDatabase = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://kidsentinel-dd697-default-rtdb.firebaseio.com',
  );

  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;

  // Initialize the child's live status in Realtime Database.
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

    if (years == 0 && months == 0) {
      return 'Less than a month';
    }

    if (years == 0) return '$months months';
    if (months == 0) return '$years years';

    return '$years years, $months months';
  }

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

  DateTime? _getBirthDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

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
                                colorScheme:
                                const ColorScheme.light(
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
                      ScaffoldMessenger.of(dialogContext)
                          .showSnackBar(
                        const SnackBar(
                          content: Text('Please enter child name'),
                        ),
                      );
                      return;
                    }

                    if (selectedBirthDate == null) {
                      ScaffoldMessenger.of(dialogContext)
                          .showSnackBar(
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

                      if (childId == null) {
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

                        final batch =
                        FirebaseFirestore.instance.batch();

                        batch.set(childRef, {
                          'name': name,
                          'birthDate': Timestamp.fromDate(
                            selectedBirthDate!,
                          ),
                          'age': age,
                          'photoUrl': photoUrl,
                          'status': 'Unknown',
                          'cameraEnabled': false,
                          'cameraOnline': false,
                          'liveStreamUrl': '',
                          'nfcConnected': false,
                          'nfcId': null,
                          'deviceOnline': false,
                          'batteryLevel': 0,
                          'obstacleDetected': false,
                          'lastEventType': '',
                          'lastEventAt': null,
                          'lastUpdated': null,
                          'connectionCodeId': code,
                          'parentIds': [],
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

                        try {
                          await _initializeChildStatus(childRef.id);
                        } catch (rtdbError) {
                          debugPrint(
                            'RTDB initialization error: $rtdbError',
                          );

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
                      } else {
                        final Map<String, dynamic> updates = {
                          'name': name,
                          'birthDate': Timestamp.fromDate(
                            selectedBirthDate!,
                          ),
                          'age': age,
                        };

                        if (selectedImage != null) {
                          final photoUrl =
                          await _uploadChildPhoto(
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
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) {
                          if (mounted) {
                            _showCodeDialog(generatedCode!);
                          }
                        });
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
                        ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(
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
                        ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(
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

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Child Added Successfully',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: purple,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Give this connection code to the parent:',
                textAlign: TextAlign.center,
              ),
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
              const SizedBox(height: 12),
              const Text(
                'This code is valid for 10 years and can be used once.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: code),
                    );

                    if (!dialogContext.mounted) return;

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Connection code copied'),
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
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChild(
      String childId,
      Map<String, dynamic> child,
      ) async {
    final parentIds = child['parentIds'] as List? ?? [];

    if (parentIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This child is connected to a parent and cannot be deleted.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Child'),
          content: const Text(
            'Are you sure you want to delete this child?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
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

    try {
      final batch = FirebaseFirestore.instance.batch();

      batch.delete(childrenCollection.doc(childId));

      final codeId = child['connectionCodeId'];

      if (codeId != null && codeId.toString().isNotEmpty) {
        batch.delete(codesCollection.doc(codeId.toString()));
      }

      await batch.commit();

      await realtimeDatabase
          .ref('childStatus/$childId')
          .remove();

      try {
        await FirebaseStorage.instance
            .ref()
            .child('children')
            .child(childId)
            .child('profile.jpg')
            .delete();
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Child deleted successfully'),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase error: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'KidSentinel',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Smart Child Monitoring System',
    );
  }

  // Log out the administrator.
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

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
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
                          onPressed: () {
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
                          onPressed: () {
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
                  Icon(
                    Icons.info_outline,
                    color: purple,
                  ),
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

          // Log out button
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
