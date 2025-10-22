import 'package:app_report/screens/main_screen.dart';
import 'package:app_report/screens/admin_screen.dart';
import 'package:app_report/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Reportes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      
      initialRoute: '/login', 
      routes: {
        '/login': (context) => LoginScreen(), // Ruta para la pantalla de login
        '/report': (context) => MainScreen(),  // Ruta para la pantalla principal
        '/admin': (context) => AdminScreen(),  // Ruta para la pantalla de admin
      },
    );
  }
}
