import 'db_helper.dart';
import 'firebase_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  /// المزامنة الكاملة بين SQLite و Firebase
  Future<void> syncStudents() async {
    // 1- هات كل الطلاب محلي + من Firebase
    final localStudents = await DBHelper.getAllStudents(); 
    final remoteStudents = await FirebaseService.instance.fetchAllStudents();

    // 2- اعمل Maps بالـ firebaseId للمقارنة السريعة
    final localMap = {
      for (var s in localStudents)
        (s.firebaseId.isNotEmpty ? s.firebaseId : s.id.toString()): s
    };

    final remoteMap = {
      for (var s in remoteStudents) s.firebaseId: s
    };

    // 3- قارن كل طالب موجود محليًا مع نسخة Firebase
    for (final local in localStudents) {
      final remote = remoteMap[local.firebaseId];

      if (remote == null) {
        // مفيش نسخة في Firebase → ابعتها للكلاود
        if (local.firebaseId.isEmpty) {
          final key = await FirebaseService.instance.addStudentToCloud(local);
          await DBHelper.updateFirebaseIdForLocal(local.id!, key);
        }
      } else {
        // موجودة في الاتنين → قارن بالأحدث
        if (remote.updatedAt > local.updatedAt) {
          await DBHelper.upsertFromServer(remote);
        } else if (local.updatedAt > remote.updatedAt) {
          await FirebaseService.instance.updateStudentOnCloud(local);
        }
      }
    }

    // 4- أي طالب في Firebase مش موجود محلي → نزّله
    for (final remote in remoteStudents) {
      if (!localMap.containsKey(remote.firebaseId)) {
        await DBHelper.upsertFromServer(remote);
      }
    }
  }
}
