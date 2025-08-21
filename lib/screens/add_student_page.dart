import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/db_helper.dart';
// import '../services/firebase_service.dart';

class AddStudentPage extends StatefulWidget {
  final String country;
  final String grade;
  final int groupNumber;

  const AddStudentPage({super.key, required this.country, required this.grade, required this.groupNumber});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _name = TextEditingController();
  final _localIdCtrl = TextEditingController();
  List<int> _availableIds = const [];
  int? _suggestedId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableIds();
  }

  Future<void> _loadAvailableIds() async {
    final free = await DBHelper.listAvailableLocalIds(
      country: widget.country,
      grade: widget.grade,
      groupNumber: widget.groupNumber,
    );
    setState(() {
      _availableIds = free.take(5).toList();
      _suggestedId = free.isNotEmpty ? free.first : 1;
      if (_localIdCtrl.text.isEmpty && _suggestedId != null) {
        _localIdCtrl.text = _suggestedId.toString();
      }
    });
  }

  void _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الاسم')),
      );
      return;
    }

    int? chosenLocalId = int.tryParse(_localIdCtrl.text.trim());
    if (chosenLocalId == null || chosenLocalId <= 0) {
      chosenLocalId = _suggestedId ?? 1;
    }
    // إذا أدخل المستخدم رقمًا يدويًا وغير موجود، اسمح باستخدامه
    final available = await DBHelper.isLocalIdAvailable(
      country: widget.country,
      grade: widget.grade,
      groupNumber: widget.groupNumber,
      localId: chosenLocalId,
    );
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم ID مستخدم بالفعل لهذه المجموعة')),
      );
      return;
    }

    final student = Student(
      name: _name.text.trim(),
      country: widget.country,
      grade: widget.grade,
      groupNumber: widget.groupNumber,
      localId: chosenLocalId,
    );

    setState(() => _saving = true);

    try {
      // تحقق من توافر localId لهذه المجموعة قبل الحفظ
      // حفظ الطالب محليًا
      await DBHelper.insertStudent(student);
      // // مزامنة إلى السحابة والحصول على firebaseId ثم حفظه محليًا
      //  final key = await FirebaseService.instance.addStudentToCloud(student);
      //  await DBHelper.updateFirebaseIdForLocal(localId, key);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الطالب بنجاح')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة طالب')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _localIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'ID للمجموعة (يبدأ من 1)',
                  suffixIcon: _suggestedId == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.lightbulb_outline),
                          tooltip: 'استخدام المقترح: ' ,
                          onPressed: () {
                            if (_suggestedId != null) {
                              _localIdCtrl.text = _suggestedId.toString();
                            }
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_availableIds.isNotEmpty)
              DropdownButton<int>(
                value: null,
                hint: const Text('اختر متاح'),
                items: _availableIds
                    .map((id) => DropdownMenuItem<int>(value: id, child: Text(id.toString())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    _localIdCtrl.text = val.toString();
                  }
                },
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('البلد: ${widget.country}')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('الصف: ${widget.grade}')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('المجموعة: ${widget.groupNumber}')),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('حفظ'),
          ),
        ]),
      ),
    );
  }
}
