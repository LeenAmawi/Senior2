
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../widgets/auth_widgets.dart';
import '../ParentScreens/ParentDashboard.dart';
import '../AdminPages/AdminHome.dart';
import 'SignUp.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginPageState();
}

class _LoginPageState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;
  String _selectedRole = 'Parent';

  final FirebaseDatabase _realtimeDatabase =
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://kidsentinel-dd697-default-rtdb.firebaseio.com',
  );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signOutQuietly() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('SIGN OUT ERROR: $e');
    }
  }

  // =========================
  // PARENT ACCESS
  // =========================

  Future<void> _completeParentAccess({
    required String uid,
    required Map<String, dynamic> parentData,
  }) async {
    final childIds = parentData['childIds'];

    if (childIds is! List || childIds.length != 1) {
      throw Exception(
        'Parent account must be linked to exactly one child.',
      );
    }

    final childId = childIds.first;
    final codeId = parentData['connectionCodeId'];

    if (childId is! String ||
        childId.isEmpty ||
        codeId is! String ||
        codeId.isEmpty) {
      throw Exception(
        'Parent connection information is missing. '
            'Please check the parent account connectionCodeId.',
      );
    }

    // Claim the parent invitation.
    await _realtimeDatabase
        .ref('parentInvites/$codeId/claimedBy')
        .set(uid);

    // Link the parent account to the child's live status.
    await _realtimeDatabase
        .ref('childStatus/$childId/parentLink')
        .set({
      'uid': uid,
      'code': codeId,
    });
  }

  // =========================
  // ADMIN ACCESS
  // =========================

  Future<void> _completeAdminAccess({
    required String uid,
    required Map<String, dynamic> adminData,
  }) async {
    final codeId = adminData['inviteCodeId'];

    if (codeId is! String || codeId.isEmpty) {
      throw Exception(
        'Admin invitation information is missing.',
      );
    }

    // Verify the admin invitation in Firestore.
    final inviteDoc = await FirebaseFirestore.instance
        .collection('adminCodes')
        .doc(codeId)
        .get();

    if (!inviteDoc.exists) {
      throw Exception(
        'Admin invitation does not exist.',
      );
    }

    final inviteData = inviteDoc.data();

    if (inviteData == null) {
      throw Exception(
        'Admin invitation information is missing.',
      );
    }

    final expiresAt = inviteData['expiresAt'];
    final usedBy = inviteData['usedBy'];
    final isUsed = inviteData['isUsed'];

    // Make sure the invitation belongs to this admin.
    if (isUsed != true || usedBy != uid) {
      throw Exception(
        'This invitation does not belong to this admin account.',
      );
    }

    // Check invitation expiration.
    if (expiresAt is! Timestamp ||
        !expiresAt.toDate().isAfter(DateTime.now())) {
      throw Exception(
        'Admin invitation has expired.',
      );
    }

    // Verify that admin access is already activated.
    final accessSnapshot =
    await _realtimeDatabase.ref('_access/$uid').get();

    if (accessSnapshot.value != 'admin') {
      throw Exception(
        'Admin permissions are not activated in Realtime Database.',
      );
    }

    debugPrint('ADMIN ACCESS VERIFIED SUCCESSFULLY');
  }

  // =========================
  // LOGIN
  // =========================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('User not found.');
      }

      await user.reload();

      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser == null || !updatedUser.emailVerified) {
        await _signOutQuietly();

        if (!mounted) return;

        showAuthError(
          context,
          'Please verify your email before logging in.',
        );
        return;
      }

      final uid = updatedUser.uid;
      final db = FirebaseFirestore.instance;

      if (_selectedRole == 'Parent') {
        // Check whether the account exists as a parent.
        final parentDoc =
        await db.collection('parents').doc(uid).get();

        if (!parentDoc.exists) {
          await _signOutQuietly();

          if (!mounted) return;

          showAuthError(
            context,
            'This account is not registered as a Parent.',
          );
          return;
        }

        final parentData = parentDoc.data();

        if (parentData == null) {
          throw Exception('Parent information is missing.');
        }

        // Set up the parent's Realtime Database access.
        await _completeParentAccess(
          uid: uid,
          parentData: parentData,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ParentDashboard(),
          ),
        );
      } else if (_selectedRole == 'Admin') {
        // Check whether the account exists as an admin.
        final adminDoc =
        await db.collection('admins').doc(uid).get();

        if (!adminDoc.exists) {
          await _signOutQuietly();

          if (!mounted) return;

          showAuthError(
            context,
            'This account is not registered as an Admin.',
          );
          return;
        }

        final adminData = adminDoc.data();

        if (adminData == null) {
          throw Exception('Admin information is missing.');
        }

        // Verify the admin's access.
        await _completeAdminAccess(
          uid: uid,
          adminData: adminData,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminHome(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email';
          break;

        case 'wrong-password':
          message = 'Wrong password provided for that user';
          break;

        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;

        default:
          message =
              e.message ?? 'Could not log in. Please try again.';
      }

      showAuthError(context, message);
    } on FirebaseException catch (e) {
      debugPrint('LOGIN FIREBASE ERROR: ${e.code}');
      debugPrint('LOGIN FIREBASE MESSAGE: ${e.message}');

      // Do not leave the user signed in if access setup failed.
      await _signOutQuietly();

      if (!mounted) return;

      showAuthError(
        context,
        'Could not complete account access. '
            'Please check your connection and try again.',
      );
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      // Sign out if the account was authenticated but setup failed.
      await _signOutQuietly();

      if (!mounted) return;

      showAuthError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // =========================
  // FORGOT PASSWORD
  // =========================

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(
      text: _email.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot password?'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Email address',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                emailController.text.trim(),
              );
            },
            child: const Text(
              'Send reset link',
              style: TextStyle(color: purple),
            ),
          ),
        ],
      ),
    );

    emailController.dispose();

    if (email == null || email.isEmpty || !mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for this email, a reset link will be sent.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = e.code == 'invalid-email'
          ? 'Please enter a valid email'
          : 'Could not send the reset link. Please try again.';

      showAuthError(context, message);
    } catch (_) {
      if (!mounted) return;

      showAuthError(
        context,
        'Something went wrong. Please try again.',
      );
    }
  }

  // =========================
  // ROLE BUTTON
  // =========================

  Widget _roleButton({
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == title;

    return Expanded(
      child: GestureDetector(
        onTap: _isLoading
            ? null
            : () {
          setState(() {
            _selectedRole = title;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 88,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFEEDFF8)
                : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? purple : Colors.transparent,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 4,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 27,
                color: isSelected ? purple : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? purple : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return AuthContainer(
      header: const AuthHeader(
        title: 'Login',
        subtitle:
        'Hi there, welcome back, please login to your account',
        imagePath: 'assets/images/auth.png',
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              hint: 'Email address',
              icon: Icons.mail_outline,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AuthButton(
              text: _isLoading ? 'Logging in...' : 'Login',
              onPressed: _isLoading ? null : _login,
            ),
            const SizedBox(height: 14),
            const Text(
              'Login as',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _roleButton(
                  title: 'Parent',
                  icon: Icons.person_outline,
                ),
                _roleButton(
                  title: 'Admin',
                  icon: Icons.person_outline,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
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
                        builder: (_) => const Signup(),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign up',
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
