
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_widgets.dart';
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;//show validation text under the fields only
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );


    } on FirebaseAuthException catch (e) {//add navigation to your home page here
      if (!mounted) return;
      String message;

      switch (e.code) {
        case 'user-not-found':message = 'No user found for that email';
          break;
        case 'wrong-password':message = 'Wrong password provided for that user';
          break;
        case 'invalid-credential':message = 'Incorrect email or password.';
          break;
        case 'invalid-email':message = 'Please enter a valid email';
          break;
        case 'too-many-requests':message = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':message = 'Network error. Please check your connection.';
          break;
        default:message = e.message ?? 'Could not log in. Please try again.';
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

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _email.text.trim(),);

    final email = await showDialog<String>(context: context,
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
          child: const Text('Cancel'),),
          TextButton(
            onPressed: () {
            Navigator.pop(
             dialogContext,
             emailController.text.trim(),);
            },
            child: const Text('Send reset link', style: TextStyle(color: purple),),),
        ],),);

    emailController.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('If an account exists for this email, a reset link will be sent.',),
        ),);} on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = e.code == 'invalid-email' ? 'Please enter a valid email' : 'Could not send the reset link. Please try again.';
      showAuthError(context, message);
    } catch (_) {
      if (!mounted) return;

      showAuthError(context, 'Something went wrong. Please try again.',);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthContainer(
      header: const AuthHeader(
      title: 'Login',
     subtitle: '',
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
          validator: validateEmail,),

            const SizedBox(height: 12),

        AuthField(
          hint: 'Password',
          icon: Icons.lock_outline,
          controller: _password,
          obscureText: _hidePassword,
          suffix: IconButton(
            onPressed: () {
            setState(() {_hidePassword = !_hidePassword;});
            },
           icon: Icon(
             _hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,),
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
                child: const Text('Forgot password?', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500,),),
              ),),

            const SizedBox(height: 18),

            AuthButton(
              text: _isLoading ? 'Logging in...' : 'Login',
              onPressed: _isLoading ? null : _login,
            ),

            const SizedBox(height: 14),

            Wrap(
            alignment: WrapAlignment.center,
              children: [
              const Text("Don't have an account? "),
              GestureDetector(onTap: () {Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => const Signup(),
                      ),);},
            child: const Text('Sign up', style: TextStyle(color: purple, fontWeight: FontWeight.bold,),),),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
