// lib/screens/second_page.dart
import 'package:flutter/material.dart';
import 'airfare_calendar_mobile.dart';

class SecondPage extends StatefulWidget {
  final String country;

  const SecondPage({
    Key? key,
    required this.country,
  }) : super(key: key);

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  String? selectedGrade;
  int? selectedGroup;

  final List<String> grades = [
    "الأول",
    "الثاني",
    "الثالث",
  ];

  final List<int> groups = [1, 2, 3];

  void _goToCalendar() {
    if (selectedGrade == null || selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر الصف ورقم المجموعة")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AirfareCalendarMobile(
          country: widget.country,
          grade: selectedGrade!,
          groupNumber: selectedGroup!,
          month: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("اختيار الصف والمجموعة (${widget.country})"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // اختيار الصف
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "اختر الصف",
                border: OutlineInputBorder(),
              ),
              value: selectedGrade,
              items: grades.map((grade) {
                return DropdownMenuItem<String>(
                  value: grade,
                  child: Text(grade),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGrade = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // اختيار المجموعة
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: "اختر رقم المجموعة",
                border: OutlineInputBorder(),
              ),
              value: selectedGroup,
              items: groups.map((group) {
                return DropdownMenuItem<int>(
                  value: group,
                  child: Text("مجموعة $group"),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGroup = value;
                });
              },
            ),
            const SizedBox(height: 30),

            // زر المتابعة
            ElevatedButton.icon(
              onPressed: _goToCalendar,
              icon: const Icon(Icons.arrow_forward),
              label: const Text("متابعة"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
