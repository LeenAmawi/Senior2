import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const Color purple = Color(0xFFAA6BD5);
  static const Color background = Color(0xFFF1F0F6);

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account email found')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Something went wrong')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Not available';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 5),

          _settingCard(
            icon: Icons.email_outlined,
            title: 'Account email',
            trailing: email,
            onTap: null,
          ),

          const SizedBox(height: 18),

          _settingCard(
            icon: Icons.lock_outline,
            title: 'Change password',
            trailing: '',
            onTap: () => _sendPasswordReset(context),
          ),

          const SizedBox(height: 18),

          _settingCard(
            icon: Icons.info_outline,
            title: 'About KidSentinel',
            trailing: '',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'KidSentinel',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Smart Child Monitoring System',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _settingCard({
    required IconData icon,
    required String title,
    required String trailing,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing.isNotEmpty)
                  Flexible(
                    child: Text(
                      trailing,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}