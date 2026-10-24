
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_widgets.dart';
import 'Login.dart';

class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key});

  @override
  State<EmailVerification> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends State<EmailVerification> {
  bool _isResending = false;
  bool _isChecking = false;

  Future<void> _resendVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showAuthError(context, 'Please sign up again.');
      return;
    }
    setState(() => _isResending = true);

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent successfully!'),),);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      showAuthError(context, e.message ?? 'Could not send verification email.',);
    } catch (_) {
      if (!mounted) return;

      showAuthError(context, 'Could not send verification email. Please try again.',);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        showAuthError(context, 'Please sign up again.');
        return;
      }

      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (updatedUser != null && updatedUser.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email verified! You can now log in.',),),);

        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => const Login(),),
        (route) => false,
        );
      } else {
        showAuthError(context, 'Your email is not verified yet. Please check your inbox.',);
      }
    } catch (_) {
      if (!mounted) return;

      showAuthError(context, 'Could not check verification status. Please try again.',);
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.white, body: SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        color: const Color(0xFFF1F1F7),
        child: Column(children: [
          Container(
          height: 40,
          decoration: BoxDecoration(
          color: purple,
           borderRadius: BorderRadius.circular(4),),

           child: Row(
             children: [
             IconButton(
               padding: EdgeInsets.zero,
               constraints: const BoxConstraints(
                 minWidth: 44,
                 minHeight: 40,),
                 onPressed: () {
                 Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                            builder: (_) => const Login(),),
                              (route) => false,);
                      },
                 icon: const Icon(
                   Icons.arrow_back,
                   color: Colors.white,
                   size: 20,
                      ),),
                    const Expanded(
                      child: Text('Email Verification',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),),),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              const SizedBox(height: 52),
              const Icon(
                Icons.mail_outline,
                size: 104,
                color: Colors.grey,
              ),

              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Verify Your Email Address',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('We have just sent an email verification link '
                    'to your email. Please check your email and '
                    'click on that link to verify your email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  ),),),

              const SizedBox(height: 52),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isResending ? null : _resendVerification,
                    icon: const Icon(
                      Icons.mail_outline,
                      size: 18,
                    ),
                    label: Text(
                      _isResending ? 'Sending...' : 'Resend Email Verification',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),),

                    style: ElevatedButton.styleFrom(backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),),
                  ),),),

              const SizedBox(height: 14),

              TextButton(
                onPressed: _isChecking ? null : _checkVerification,
                child: Text(_isChecking ? 'Checking...' : "I've verified my email",
                  style: const TextStyle(color: purple, fontWeight: FontWeight.bold,),),),
            ],
          ),
        ),
      ),
    );
  }
}
