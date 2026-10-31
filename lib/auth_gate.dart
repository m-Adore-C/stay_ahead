import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _fbInit;

  @override
  void initState() {
    super.initState();
    _fbInit = _initFirebase();
  }

  Future<bool> _initFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyD2zF09gOCyhX6_jgd0xNl_1jJ5hg9i-PM",
            appId: "1:180689536000:web:f0da013175abafaa8244e5",
            messagingSenderId: "180689536000",
            projectId: "stayahead-2bae9",
            authDomain: "stayahead-2bae9.firebaseapp.com",
            storageBucket: "stayahead-2bae9.firebasestorage.app",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      debugPrint('Firebase async init error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _fbInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == true && Firebase.apps.isNotEmpty) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (authSnapshot.data == null) {
                return const LoginScreen();
              }
              return const DashboardScreen();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}