
import 'package:flutter/material.dart';

const purple = Color(0xFFA66BD2);
const lightPurple = Color(0xFFF0E2FA);
const blue = Color(0xFF008CFF);

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';

  if (email.isEmpty) {
    return 'Email is required';
  }

  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  return null;
}

String? validateRequired(String? value, String field) {
  if (value == null || value.trim().isEmpty) {
    return '$field is required';
  }

  return null;
}

void showAuthError(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,),
          child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 36,
          ),),
          const SizedBox(height: 12),
            const Text('ERROR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12),),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK', style: TextStyle(color: purple),
              ),),
          ],
        ),
      ),
    ),
  );
}

class AuthField extends StatefulWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final String? serverError;

  const AuthField({
    super.key,
    required this.hint,
    this.icon,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.serverError,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hasTyped = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      validator: (value) => widget.validator?.call(value),
      autovalidateMode: _hasTyped ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      onChanged: (value) {
        if (!_hasTyped) {
          setState(() {
            _hasTyped = true;
          });
        }
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: widget.icon != null ? Icon(widget.icon) : null,
        suffixIcon: widget.suffix,
        errorText: widget.serverError,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: purple),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: purple),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: purple,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 11,
        ),
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
          ),),),);
  }
}

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
  return SizedBox(width: 200, height: 180,
    child: Stack(
      children: [Positioned.fill(
       child: Image.asset(imagePath, fit: BoxFit.contain,
       errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey,);
              },
            ),),
        Positioned(
        top: 30,
        left: 15,
        right: 15,
        child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9252B5), fontSize: 23, fontWeight: FontWeight.bold,),),),
        ],
      ),
    );
  }
}

class AuthContainer extends StatelessWidget {
  final Widget child;
  final Widget? header;
  const AuthContainer({
    super.key,
    required this.child,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.white,
     body: SafeArea(
     child: Center(
     child: SingleChildScrollView(
     padding: const EdgeInsets.symmetric(
       horizontal: 24,
       vertical: 20,),
       child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360,),
       child: Column(mainAxisSize: MainAxisSize.min,
       children: [
        if (header != null) header!,
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22,),
        color: Colors.white,
         child: child,),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
