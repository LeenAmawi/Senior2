
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

      // 1. Create Firebase Authentication account
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Could not create account');
      }

      newUser = user;

      final uid = user.uid;
      final firstName = _firstName.text.trim();
      final lastName = _lastName.text.trim();

      // 2. Read and validate connection code
      final codeRef =
      db.collection('connectionCodes').doc(codeId);

      final codeSnapshot = await codeRef.get();

      if (!codeSnapshot.exists) {
        throw Exception('Invalid connection code');
      }

      final codeData = codeSnapshot.data()!;

      final childId = codeData['childId'] as String?;
      final isUsed = codeData['isUsed'] as bool?;
      final expiresAt = codeData['expiresAt'] as Timestamp?;

      if (childId == null ||
          isUsed != false ||
          expiresAt == null ||
          !expiresAt.toDate().isAfter(DateTime.now())) {
        throw Exception('Invalid or expired connection code');
      }

      // 3. Prepare Firestore references
      final parentRef = db.collection('parents').doc(uid);
      final childRef = db.collection('children').doc(childId);

      // 4. Link parent, child, and code atomically
      final batch = db.batch();

      batch.set(parentRef, {
        'firstName': firstName,
        'lastName': lastName,
        'email': _email.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'childIds': [childId],
      });

      batch.update(childRef, {
        'parentIds': FieldValue.arrayUnion([uid]),
      });

      batch.update(codeRef, {
        'isUsed': true,
        'usedBy': uid,
      });

      await batch.commit();

      batchCommitted = true;

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
      // Delete the new account only if Firestore linking did not finish.
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

      if (e.code == 'permission-denied') {
        showAuthError(
          context,
          'Connection failed. Please check the connection code.',
        );
      } else {
        showAuthError(
          context,
          'Could not complete registration. Please try again.',
        );
      }
    } catch (e) {
      if (newUser != null && !batchCommitted) {
        try {
          await newUser.delete();
        } catch (_) {}
      }

      if (!mounted) return;

      final message = e.toString();

      if (message.contains('Invalid connection code')) {
        showAuthError(context, 'Invalid connection code');
      } else if (message.contains('expired')) {
        showAuthError(context, 'Connection code has expired');
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
        subtitle: '',
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
              hint: 'Child Connection Code',
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
                const Text('Already have an account? '),
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
