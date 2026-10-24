
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return; //Validate required fields and email format
    final password = _password.text;//Check password strength before creating the account
    final isStrongPassword = password.length >= 8 && RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[0-9]').hasMatch(password);

    if (!isStrongPassword) {
      showAuthError(context, 'Too weak password');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: password,);
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(
          '${_firstName.text.trim()} ${_lastName.text.trim()}',
        );
        await user.sendEmailVerification();
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmailVerification(),),);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'email-already-in-use':message = 'The account already exists for that email';
          break;

        case 'invalid-email':message = 'Please enter a valid email';
          break;

        case 'weak-password':message = 'Too weak password';
          break;

        default:message = e.message ?? 'Could not create the account.';
      }

      showAuthError(context, message);
    } catch (_) {
      if (!mounted) return;

      showAuthError(context, 'Something went wrong. Please try again.',);
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
      child: Form(key: _formKey,
      child: Column(
      children: [AuthField(
      hint: 'First Name',
      controller: _firstName,
      validator: (value) => validateRequired(value, 'First name'),),

      const SizedBox(height: 12),

      AuthField(hint: 'Last Name',
      controller: _lastName,
      validator: (value) =>
      validateRequired(value, 'Last name'),),

        const SizedBox(height: 12),

        AuthField(hint: 'Email address',
        icon: Icons.mail_outline,
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        validator: validateEmail,),

        const SizedBox(height: 12),

        AuthField(hint: 'Password',
        icon: Icons.lock_outline,
       controller: _password,
       obscureText: _hidePassword,
       suffix: IconButton(
      onPressed: () {
      setState(() {
       _hidePassword = !_hidePassword;});
       },
       icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,),),
          validator: validatePassword,),

            const SizedBox(height: 12),

       AuthField(hint: 'Confirm password',
       icon: Icons.lock_outline,
       controller: _confirmPassword,
       obscureText: _hideConfirmPassword,
       suffix: IconButton(
       onPressed: () {
        setState(() {
       _hideConfirmPassword = !_hideConfirmPassword;});
       },
       icon: Icon(
       _hideConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,),
       ),
        validator: (value) {
        if (value == null || value.isEmpty) {
        return 'Please confirm your password';
        }

        if (value != _password.text) {
        return 'Passwords do not match';}
        return null;
        },),

        const SizedBox(height: 18),

            AuthButton(
            text: _isLoading ? 'Creating account...' : 'Sign up',
            onPressed: _isLoading ? null : _signup,),

            const SizedBox(height: 14),

            Wrap(
              alignment: WrapAlignment.center,
              children: [
            const Text('Already have an account? '),
            GestureDetector(
            onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const Login(),
            ),);},
            child: const Text('Log in', style: TextStyle(color: purple, fontWeight: FontWeight.bold,),
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
