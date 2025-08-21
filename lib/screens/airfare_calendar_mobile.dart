import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/db_helper.dart';
import '../services/firebase_service.dart';
import '../services/SyncService.dart';

import 'add_student_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
class AirfareCalendarMobile extends StatefulWidget {
  final String country;
  final String grade;
  final int groupNumber;

  const AirfareCalendarMobile({
    Key? key,
    required this.country,
    required this.grade,
    required this.groupNumber,
    required String month,
  }) : super(key: key);

  @override
  State<AirfareCalendarMobile> createState() => _AirfareCalendarMobileState();
}

class _AirfareCalendarMobileState extends State<AirfareCalendarMobile> {
  List<Student> students = [];
  bool loading = true;
  bool showDeletedOnly = false;

  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<int> selectedLocalIds = {};

  final List<String> months = ["8","9", "10", "11", "12", "1", "2", "3", "4", "5", "6"];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != query) {
        query = q;
        _loadStudents();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _loadStudents() async {
    setState(() => loading = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
       await SyncService.instance.syncStudents();
      }

      // دايمًا عرض البيانات من SQLite
      if (showDeletedOnly) {
        students = await DBHelper.searchDeletedStudents(
          query,
          country: widget.country,
          grade: widget.grade,
          groupNumber: widget.groupNumber,
        );
      } else {
        students = await DBHelper.searchStudents(
          query,
          country: widget.country,
          grade: widget.grade,
          groupNumber: widget.groupNumber,
        );
      }

      // تم ترتيب النتائج من المصدر بـ id ASC
    } catch (e) {
      debugPrint('Load students error: $e');
      // fallback: لو فيه مشكلة، عرض من SQLite لو فيه بيانات
      students = showDeletedOnly
          ? await DBHelper.searchDeletedStudents(
              query,
              country: widget.country,
              grade: widget.grade,
              groupNumber: widget.groupNumber,
            )
          : await DBHelper.searchStudents(
              query,
              country: widget.country,
              grade: widget.grade,
              groupNumber: widget.groupNumber,
            );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _toggleSelect(Student s) async {
    if (s.id == null) return;
    setState(() {
      if (selectedLocalIds.contains(s.id)) {
        selectedLocalIds.remove(s.id);
      } else {
        selectedLocalIds.add(s.id!);
      }
    });
  }

  int _countMapValues(Map<String, int> m) {
    return m.values.fold<int>(0, (prev, el) => prev + el);
  }

  Future<void> _openEditDialog(Student s) async {
    final tempAbsence = Map<String, int>.from(s.absence);
    final tempFees = Map<String, int>.from(s.fees);
    final tempForget = Map<String, int>.from(s.forgetCard);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateDialog) {
          Widget monthToggleRow(String monthKey, String label) {
            
            final ab = tempAbsence[monthKey] ?? 0;
            final fe = tempFees[monthKey] ?? 0;
            final fo = tempForget[monthKey] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 42, child: Text(label, textAlign: TextAlign.start)),
                  _numberInputWithArrows(
                    value: ab,
                    onChanged: (v) => setStateDialog(() => tempAbsence[monthKey] = v),
                    label: 'غياب',
                  ),
                  const SizedBox(width: 10),
                  _tinyToggleButton(
                    value: fe,
                    onChanged: (v) => setStateDialog(() => tempFees[monthKey] = v),
                    label: 'دفع',
                  ),
                  const SizedBox(width: 10),
                  _numberInputWithArrows(
                    value: fo,
                    onChanged: (v) => setStateDialog(() => tempForget[monthKey] = v),
                    label: 'نسيان',
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: Text('تعديل ${s.name}'),
            contentPadding: const EdgeInsets.all(20),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: months.map((m) {
                    final label = _monthLabel(m);
                    return monthToggleRow(m, label);
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  s.absence = tempAbsence;
                  s.fees = tempFees;
                  s.forgetCard = tempForget;
                  s.updatedAt = DateTime.now().millisecondsSinceEpoch;
                  await DBHelper.updateStudent(s);
                  await FirebaseService.instance.updateStudentOnCloud(s);
                  await _loadStudents();
                  Navigator.pop(ctx2);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _restoreSelected() async {
    if (selectedLocalIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الاسترجاع'),
        content: Text('هل تريد استرجاع ${selectedLocalIds.length} طالب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('استرجاع')),
        ],
      ),
    );
    if (confirm != true) return;

    for (final localId in selectedLocalIds) {
      final s = students.firstWhere(
        (e) => e.id == localId,
        orElse: () => Student(name: '', country: '', grade: '', groupNumber: 0),
      );
      if (s.id != null) {
        await DBHelper.restoreStudent(s.id!);
        if (s.firebaseId.isNotEmpty) {
          s.deleted = false;
          s.updatedAt = DateTime.now().millisecondsSinceEpoch;
          await FirebaseService.instance.updateStudentOnCloud(s);
        }
      }
    }
    selectedLocalIds.clear();
    await _loadStudents();
  }

  Future<void> _hardDeleteSelected() async {
    if (selectedLocalIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف النهائي'),
        content: Text('سيتم حذف ${selectedLocalIds.length} طالب نهائيًا. لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirm != true) return;

    for (final localId in selectedLocalIds) {
      await DBHelper.deleteStudentHard(localId);
    }
    selectedLocalIds.clear();
    await _loadStudents();
  }

  Widget _tinyToggleButton({
    required int value,
    required void Function(int) onChanged,
    required String label,
  }) 
  
  
  {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(value == 0 ? 1 : 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: value == 1 ? Colors.green.shade400 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value == 1 ? 'نعم' : 'لا',
              style: TextStyle(color: value == 1 ? Colors.white : Colors.black,fontSize:10),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _numberInputWithArrows({
    required int value,
    required void Function(int) onChanged,
    required String label,
  }) 
  
  {
    return Row(
      children: [
        // Number display
        Container(
          width: 25,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Up/Down arrows
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => onChanged(value + 1),
              child: Container(
                width: 24,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),
                ),
                child: const Icon(Icons.keyboard_arrow_up, size: 14),
              ),
            ),
            GestureDetector(
              onTap: () => onChanged(value > 0 ? value - 1 : 0),
              child: Container(
                width: 24,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
                child: const Icon(Icons.keyboard_arrow_down, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }


  Future<void> _deleteSelected() async {
    if (selectedLocalIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف ${selectedLocalIds.length} طالب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;

    for (final localId in selectedLocalIds) {
      final s = students.firstWhere((e) => e.id == localId, orElse: () => Student(name: '', country: '', grade: '', groupNumber: 0));
      if (s.firebaseId.isNotEmpty) {
        await FirebaseService.instance.softDeleteOnCloud(s);
      }
      await DBHelper.softDeleteStudent(localId);
    }
    selectedLocalIds.clear();
    await _loadStudents();
  }

  String _monthLabel(String key) {
    switch (key) {
      case '8': return 'أغسطس';
      case '9': return 'سبتمبر';
      case '10': return 'أكتوبر';
      case '11': return 'نوفمبر';
      case '12': return 'ديسمبر';
      case '1': return 'يناير';
      case '2': return 'فبراير';
      case '3': return 'مارس';
      case '4': return 'أبريل';
      case '5': return 'مايو';
      case '6': return 'يونيو';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    // عرض كقائمة رأسية بعرض الشاشة

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة الطلاب'),
        actions: [
          IconButton(
            tooltip: selectedLocalIds.length == students.length && students.isNotEmpty
                ? 'إلغاء تحديد الكل'
                : 'تحديد الكل',
            onPressed: () {
              setState(() {
                if (selectedLocalIds.length == students.length && students.isNotEmpty) {
                  selectedLocalIds.clear();
                } else {
                  selectedLocalIds
                    ..clear()
                    ..addAll(students.where((s) => s.id != null).map((s) => s.id!));
                }
              });
            },
            icon: Icon(
              selectedLocalIds.length == students.length && students.isNotEmpty
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
          ),
          if (selectedLocalIds.isNotEmpty)
            IconButton(
              tooltip: showDeletedOnly ? 'استرجاع المحدد' : 'حذف المحدد',
              onPressed: showDeletedOnly ? _restoreSelected : _deleteSelected,
              icon: Icon(showDeletedOnly ? Icons.restore : Icons.delete_forever),
            ),
          if (showDeletedOnly && selectedLocalIds.isNotEmpty)
            IconButton(
              tooltip: 'حذف نهائي المحدد',
              onPressed: _hardDeleteSelected,
              icon: const Icon(Icons.delete_forever),
            ),
          IconButton(
            tooltip: showDeletedOnly ? 'عرض غير المحذوفين' : 'عرض المحذوفين فقط',
            onPressed: () async {
              setState(() => showDeletedOnly = !showDeletedOnly);
              await _loadStudents();
            },
            icon: Icon(showDeletedOnly ? Icons.visibility : Icons.visibility_off),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          query = '';
                          _loadStudents();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : students.isEmpty
                    ? Center(
                        child: Text(
                            'لا يوجد طلاب في ${widget.country} - ${widget.grade} - مجموعة ${widget.groupNumber}'),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView.separated(
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final s = students[i];
                            final absenceCount = _countMapValues(s.absence);
                            final feesCount = _countMapValues(s.fees);
                            final forgetCount = _countMapValues(s.forgetCard);
                            final isSelected =
                                (s.id != null && selectedLocalIds.contains(s.id));

                            return GestureDetector(
                              onTap: () => _openEditDialog(s),
                              onLongPress: () => _toggleSelect(s),
                              child: Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(minHeight: 80),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.red.shade50 : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? Colors.red : Colors.grey.shade300,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2))
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.green.shade400,
                                      child: Text(
                                        ((s.localId ?? s.id) ?? '-').toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            s.name,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'البلد: ${s.country} • الصف: ${s.grade} • المجموعة: ${s.groupNumber}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            textDirection: TextDirection.rtl,
                                            children: [
                                              _miniStat(Icons.event_busy,
                                                  absenceCount.toString(), Colors.orange),
                                              const SizedBox(width: 8),
                                              _miniStat(Icons.payments,
                                                  feesCount.toString(), Colors.blue),
                                              const SizedBox(width: 8),
                                              _miniStat(Icons.credit_card_off,
                                                  forgetCount.toString(), Colors.purple),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 48,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            tooltip: isSelected ? 'إلغاء التحديد' : 'تحديد الطالب',
                                            onPressed: () => _toggleSelect(s),
                                            icon: Icon(
                                              isSelected
                                                  ? Icons.check_box
                                                  : Icons.check_box_outline_blank,
                                            ),
                                            color: isSelected ? Colors.red : Colors.grey,
                                          ),
                                          if (showDeletedOnly && s.id != null)
                                            IconButton(
                                              tooltip: 'استرجاع',
                                              onPressed: () async {
                                                await DBHelper.restoreStudent(s.id!);
                                                if (s.firebaseId.isNotEmpty) {
                                                  final restored = Student(
                                                    id: s.id,
                                                    firebaseId: s.firebaseId,
                                                    name: s.name,
                                                    country: s.country,
                                                    grade: s.grade,
                                                    groupNumber: s.groupNumber,
                                                    absence: s.absence,
                                                    fees: s.fees,
                                                    forgetCard: s.forgetCard,
                                                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                                                    deleted: false,
                                                  );
                                                  await FirebaseService.instance.updateStudentOnCloud(restored);
                                                }
                                                await _loadStudents();
                                              },
                                              icon: const Icon(Icons.restore),
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: showDeletedOnly
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddStudentPage(
                      country: widget.country,
                      grade: widget.grade,
                      groupNumber: widget.groupNumber,
                    ),
                  ),
                );
                if (added == true) {
                  await _loadStudents(); // تحميل فقط إذا أضيف طالب جديد
                }
              },
              child: const Icon(Icons.add),
            ),

    );
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
