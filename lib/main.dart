import 'package:flutter/material.dart';
import 'package:progress/screens/auth_screen.dart'; 
import 'package:progress/services/notification_service.dart'; 


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(); 
  runApp(const ProgressApp());
}

class ProgressApp extends StatelessWidget {
  const ProgressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(),
        useMaterial3: true,
      ),
      home: const AuthScreen(), // Starts with the biometric lock
    );
  }
}