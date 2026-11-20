
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Auth/Login.dart';
import 'firebase_options.dart';
import 'Starting/Start1.dart';
import 'ParentScreens/ParentDashboard.dart';
import 'AdminPages/AdminHome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const KidsentialApp());
}

class KidsentialApp extends StatelessWidget {
  const KidsentialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kidsential Kindergarten',
      home: const AppGate(),
      routes: {
        '/login': (context) => const Login(),
      },
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  Future<bool> _checkWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('welcomeSeen') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkWelcome(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.data!) {
          return const Start1();
        }

        return const AuthGate();
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const Login();
        }

        return AuthRedirector(user: user);
      },
    );
  }
}

class AuthRedirector extends StatefulWidget {
  final User user;

  const AuthRedirector({
    super.key,
    required this.user,
  });

  @override
  State<AuthRedirector> createState() => _AuthRedirectorState();
}

class _AuthRedirectorState extends State<AuthRedirector> {
  late Future<Widget> _destination;

  @override
  void initState() {
    super.initState();
    _destination = _getDestination();
  }

  Future<Widget> _getDestination() async {
    try {
      await widget.user.reload();

      final user = FirebaseAuth.instance.currentUser;

      if (user == null || !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        return const Login();
      }

      final db = FirebaseFirestore.instance;

      final parentDoc = await db
          .collection('parents')
          .doc(user.uid)
          .get();

      if (parentDoc.exists) {
        return const ParentDashboard();
      }

      final adminDoc = await db
          .collection('admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        return const AdminHome();
      }

      await FirebaseAuth.instance.signOut();
      return const Login();
    } catch (e) {
      debugPrint('AUTH REDIRECT ERROR: $e');
      return const Scaffold(
        body: Center(
          child: Text('Could not verify account. Please check connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Login();
        }

        return snapshot.data!;
      },
    );
  }
}
