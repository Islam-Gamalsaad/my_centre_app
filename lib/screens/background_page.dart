// lib/screens/background_page.dart
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import 'second_page.dart';

class BackgroundPage extends StatelessWidget {
  const BackgroundPage({super.key});

  void _openSecondPage(BuildContext context, String country) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SecondPage(
          country: country,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية بتدرج الألوان
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.greenAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // دائرة كبيرة في الأعلى-يسار
          Positioned(
            left: 50,
            top: 100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // دائرة كبيرة في الأسفل-يمين
          Positioned(
            right: 60,
            bottom: 100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // المحتوى الرئيسي في المنتصف
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CustomButton(
                  title: 'نقباس',
                  buttons: ["نقباس"],
                  onPressed: (title) => _openSecondPage(context, 'نقباس'),
                ),
                const SizedBox(height: 40),
                CustomButton(
                  title: 'العرب',
                  buttons: ['العرب'],
                  onPressed: (title) => _openSecondPage(context, 'العرب'),
                ),
                const SizedBox(height: 40),
                CustomButton(
                  title: 'بتمدة',
                  buttons: ['بتمدة'],
                  onPressed: (title) => _openSecondPage(context, 'بتمدة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
