import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String title; // اسم البلد أو العنوان
  final List<String> buttons; // قائمة الأزرار الثانوية
  final void Function(String) onPressed; // دالة تنفذ عند الضغط على أي زر

  const CustomButton({
    super.key,
    required this.title,
    required this.buttons,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // عنوان البلد
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        // الأزرار
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: buttons.map((btnTitle) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => onPressed(btnTitle),
              child: Text(
                btnTitle,
                style: const TextStyle(fontSize: 18),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
