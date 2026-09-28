import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:progress/screens/timeline_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;

    try {
      setState(() {
        _isAuthenticating = true;
      });

      // Triggers the biometric prompt
      authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to view your progress log',
        biometricOnly: false, // Allows device PIN/pattern if biometrics fail
        persistAcrossBackgrounding: true, // Keeps auth active if app goes to background temporarily
        sensitiveTransaction: true,
      );
    } catch (e) {
      debugPrint("Authentication error: $e");
    }

    if (!mounted) return;

    setState(() {
      _isAuthenticated = authenticated;
      _isAuthenticating = false;
    });

    // If successful, navigate to the Timeline screen and replace the Auth screen
    if (_isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TimelineScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.lock,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'App Locked',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            // Show a retry button if authentication was canceled or failed
            if (!_isAuthenticating && !_isAuthenticated)
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(LucideIcons.fingerprint),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            if (_isAuthenticating)
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}