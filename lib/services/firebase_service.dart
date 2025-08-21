import 'package:firebase_database/firebase_database.dart';
import '../models/student_model.dart';
import 'db_helper.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final DatabaseReference _root = FirebaseDatabase.instance.ref('students');

  Future<String> addStudentToCloud(Student student) async {
    final ref = _root.push();
    final data = _toFirebaseMap(student);
    await ref.set(data);
    return ref.key!;
  }

  Future<void> updateStudentOnCloud(Student student) async {
    if (student.firebaseId.isEmpty) return;
    final ref = _root.child(student.firebaseId);
    final data = _toFirebaseMap(student);
    await ref.update(data);
  }

  Future<void> softDeleteOnCloud(Student student) async {
    if (student.firebaseId.isEmpty) return;
    final ref = _root.child(student.firebaseId);
    await ref.update({
      'deleted': true,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Student>> fetchStudents({
    required String country,
    required String grade,
    required int groupNumber,
  }) async {
    final q = _root
        .orderByChild('country_grade_group')
        .equalTo('${country}_${grade}_$groupNumber');
    final snap = await q.get();
    final list = <Student>[];
    if (snap.exists && snap.value is Map) {
      final map = (snap.value as Map).cast<String, dynamic>();
      map.forEach((key, value) {
        final data = Map<String, dynamic>.from(value as Map);
        final s = _fromFirebaseMap(key, data);
        if (!s.deleted) list.add(s);
      });
    }
    return list;
  }

  Future<List<Student>> fetchAllStudents() async {
    final snap = await _root.get();
    final list = <Student>[];
    if (snap.exists && snap.value is Map) {
      final map = (snap.value as Map).cast<String, dynamic>();
      map.forEach((key, value) {
        final data = Map<String, dynamic>.from(value as Map);
        final s = _fromFirebaseMap(key, data);
        if (!s.deleted) list.add(s);
      });
    }
    return list;
  }

  Map<String, dynamic> _toFirebaseMap(Student s) {
    return {
      'localId': s.localId,
      'name': s.name,
      'country': s.country,
      'grade': s.grade,
      'groupNumber': s.groupNumber,
      'absence': s.absence,
      'fees': s.fees,
      'forgetCard': s.forgetCard,
      'updatedAt': s.updatedAt,
      'deleted': s.deleted,
      // for composite queries
      'country_grade_group': '${s.country}_${s.grade}_${s.groupNumber}',
    };
  }

  Student _fromFirebaseMap(String key, Map<String, dynamic> m) {
    Map<String, int> parseIntMap(dynamic value) {
      if (value is Map) {
        final result = <String, int>{};
        value.forEach((k, v) {
          final kk = k.toString();
          if (v is num) {
            result[kk] = v.toInt();
          } else {
            final parsed = int.tryParse(v.toString()) ?? 0;
            result[kk] = parsed;
          }
        });
        return result;
      }
      return <String, int>{};
    }

    int parseInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;
    bool parseBool(dynamic v) => (v is bool) ? v : v.toString() == 'true';

    return Student(
      firebaseId: key,
      localId: parseInt(m['localId']),
      name: (m['name'] ?? '').toString(),
      country: (m['country'] ?? '').toString(),
      grade: (m['grade'] ?? '').toString(),
      groupNumber: parseInt(m['groupNumber']),
      absence: parseIntMap(m['absence']),
      fees: parseIntMap(m['fees']),
      forgetCard: parseIntMap(m['forgetCard']),
      updatedAt: parseInt(m['updatedAt']),
      deleted: parseBool(m['deleted']),
    );
  }

  // Simple one-way sync: push local new items to cloud
  Future<void> syncLocalToCloud() async {
    final unsynced = await DBHelper.getUnsyncedItems();
    for (final s in unsynced) {
      if (s.deleted) {
        await softDeleteOnCloud(s);
        continue;
      }
      if (s.firebaseId.isEmpty) {
        final key = await addStudentToCloud(s);
        await DBHelper.updateFirebaseIdForLocal(s.id!, key);
      } else {
        await updateStudentOnCloud(s);
      }
    }
  }
}


