
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/auth_widgets.dart';
import 'Login.dart';
import 'EmailVerification.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupPageState();
}

class _SignupPageState extends State<Signup> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _connectionCode = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _connectionCode.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final password = _password.text;

    final isStrongPassword = password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);

    if (!isStrongPassword) {
      showAuthError(context, 'Too weak password');
      return;
    }

    setState(() => _isLoading = true);

    User? newUser;
    bool batchCommitted = false;

    try {
      final db = FirebaseFirestore.instance;
      final codeId = _connectionCode.text.trim();

      final firstName = _firstName.text.trim();
      final lastName = _lastName.text.trim();
      final email = _email.text.trim();

      // 1. Create Firebase Authentication account
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Could not create account');
      }

      newUser = user;

      final uid = user.uid;

      // 2. Check Parent connection code first
      final parentCodeRef =
      db.collection('connectionCodes').doc(codeId);

      DocumentSnapshot<Map<String, dynamic>>? parentCodeSnapshot;

      try {
        parentCodeSnapshot = await parentCodeRef.get();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
      }

      // 3. If it is a valid Parent code
      if (parentCodeSnapshot != null &&
          parentCodeSnapshot.exists) {
        final codeData = parentCodeSnapshot.data()!;

        final childId = codeData['childId'] as String?;
        final isUsed = codeData['isUsed'] as bool?;
        final expiresAt = codeData['expiresAt'] as Timestamp?;

        if (childId == null ||
            childId.isEmpty ||
            isUsed != false ||
            expiresAt == null ||
            !expiresAt.toDate().isAfter(DateTime.now())) {
          throw Exception('Invalid or expired connection code');
        }

        final parentRef = db.collection('parents').doc(uid);
        final childRef = db.collection('children').doc(childId);

        // Link Parent, Child, and code atomically
        final batch = db.batch();

        batch.set(parentRef, {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'childIds': [childId],
        });

        batch.update(childRef, {
          'parentIds': FieldValue.arrayUnion([uid]),
        });

        batch.update(parentCodeRef, {
          'isUsed': true,
          'usedBy': uid,
        });

        await batch.commit();

        batchCommitted = true;
      }

      // 4. Otherwise, check Admin invitation code
      else {
        final adminCodeRef =
        db.collection('adminCodes').doc(codeId);

        final adminCodeSnapshot = await adminCodeRef.get();

        if (!adminCodeSnapshot.exists) {
          throw Exception('Invalid invitation code');
        }

        final codeData = adminCodeSnapshot.data()!;

        final isUsed = codeData['isUsed'] as bool?;
        final expiresAt = codeData['expiresAt'] as Timestamp?;

        if (isUsed != false ||
            expiresAt == null ||
            !expiresAt.toDate().isAfter(DateTime.now())) {
          throw Exception('Invalid or expired admin code');
        }

        final adminRef = db.collection('admins').doc(uid);

        final batch = db.batch();

        batch.set(adminRef, {
          'name': '$firstName $lastName',
          'email': email,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'inviteCodeId': codeId,
        });

        batch.update(adminCodeRef, {
          'isUsed': true,
          'usedBy': uid,
        });

        await batch.commit();

        batchCommitted = true;
      }

      // 5. Update profile and send verification email
      await user.updateDisplayName('$firstName $lastName');
      await user.sendEmailVerification();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const EmailVerification(),
        ),
      );

    } on FirebaseAuthException catch (e) {
      if (newUser != null && !batchCommitted) {
        try {
          await newUser.delete();
        } catch (_) {}
      }

      if (!mounted) return;

      String message;

      if (batchCommitted) {
        message =
        'Account created, but email verification could not be sent. Please try again later.';
      } else {
        switch (e.code) {
          case 'email-already-in-use':
            message = 'The account already exists for that email';
            break;
          case 'invalid-email':
            message = 'Please enter a valid email';
            break;
          case 'weak-password':
            message = 'Too weak password';
            break;
          default:
            message = e.message ?? 'Could not create the account.';
        }
      }

      showAuthError(context, message);

    } on FirebaseException catch (e) {
      debugPrint('FIRESTORE ERROR CODE: ${e.code}');
      debugPrint('FIRESTORE ERROR MESSAGE: ${e.message}');

      if (newUser != null && !batchCommitted) {
        try {
          await newUser.delete();
        } catch (_) {}
      }

      if (!mounted) return;

      if (batchCommitted) {
        showAuthError(
          context,
          'Account created, but email verification could not be sent.',
        );
      } else if (e.code == 'permission-denied' ||
          e.code == 'not-found') {
        showAuthError(
          context,
          'Invalid or expired invitation code.',
        );
      } else {
        showAuthError(
          context,
          'Could not complete registration. Please try again.',
        );
      }

    } catch (e) {
      debugPrint('SIGNUP ERROR: $e');

      if (newUser != null && !batchCommitted) {
        try {
          await newUser.delete();
        } catch (_) {}
      }

      if (!mounted) return;

      final message = e.toString();

      if (message.contains('Invalid invitation code') ||
          message.contains('Invalid or expired')) {
        showAuthError(
          context,
          'Invalid or expired connection code.',
        );
      } else {
        showAuthError(
          context,
          'Something went wrong. Please try again.',
        );
      }

    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthContainer(
      header: const AuthHeader(
        title: 'Sign up',
        subtitle: 'Enter your details to create an account',
        imagePath: 'assets/images/auth.png',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              hint: 'First Name',
              controller: _firstName,
              validator: (value) =>
                  validateRequired(value, 'First name'),
            ),

            const SizedBox(height: 12),

            AuthField(
              hint: 'Last Name',
              controller: _lastName,
              validator: (value) =>
                  validateRequired(value, 'Last name'),
            ),

            const SizedBox(height: 12),

            AuthField(
              hint: 'Email address',
              icon: Icons.mail_outline,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
            ),

            const SizedBox(height: 12),

            AuthField(
              hint: 'Connection Code',
              icon: Icons.vpn_key_outlined,
              controller: _connectionCode,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the connection code';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            AuthField(
              hint: 'Password',
              icon: Icons.lock_outline,
              controller: _password,
              obscureText: _hidePassword,
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _hidePassword = !_hidePassword;
                  });
                },
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: validatePassword,
            ),

            const SizedBox(height: 12),

            AuthField(
              hint: 'Confirm password',
              icon: Icons.lock_outline,
              controller: _confirmPassword,
              obscureText: _hideConfirmPassword,
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _hideConfirmPassword =
                    !_hideConfirmPassword;
                  });
                },
                icon: Icon(
                  _hideConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }

                if (value != _password.text) {
                  return 'Passwords do not match';
                }

                return null;
              },
            ),

            const SizedBox(height: 18),

            AuthButton(
              text: _isLoading
                  ? 'Creating account...'
                  : 'Sign up',
              onPressed: _isLoading ? null : _signup,
            ),

            const SizedBox(height: 14),

            Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Login(),
                      ),
                    );
                  },
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      color: purple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
