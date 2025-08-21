import 'package:flutter/material.dart';
import 'screens/background_page.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // مهم قبل Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // إضافة const إذا ممكن

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo', // لو حابب تضيف خط عربي
      ),
      home: const BackgroundPage(),
    );
  }
}
