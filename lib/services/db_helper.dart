import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/student_model.dart';

class DBHelper {
  static Database? _db;
  static const String _table = 'students';

  static Future<Database> database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'students.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE $_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            localId INTEGER,
            firebaseId TEXT,
            name TEXT,
            country TEXT,
            grade TEXT,
            groupNumber INTEGER,
            absence TEXT,
            fees TEXT,
            forgetCard TEXT,
            updatedAt INTEGER,
            deleted INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_students_country_grade_group ON $_table(country, grade, groupNumber)');
        await db.execute('CREATE INDEX idx_students_name ON $_table(name)');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_localid ON $_table(country, grade, groupNumber, localId)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE $_table ADD COLUMN localId INTEGER');
          } catch (_) {}
          try {
            await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_localid ON $_table(country, grade, groupNumber, localId)');
          } catch (_) {}
        }
      },
      onOpen: (db) async {
        // تأكيد المخطط عند الفتح (للتعامل مع حالات الهوت-ريلود حيث قد لا يعمل onUpgrade)
        await _ensureSchema(db);
      },
    );
    return _db!;
  }

  static Future<void> _ensureSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($_table)');
      final hasLocalId = info.any((row) => (row['name'] as String?) == 'localId');
      if (!hasLocalId) {
        try {
          await db.execute('ALTER TABLE $_table ADD COLUMN localId INTEGER');
        } catch (_) {}
      }
      // تأكد من وجود الفهرس الفريد
      try {
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_localid ON $_table(country, grade, groupNumber, localId)');
      } catch (_) {}
    } catch (_) {
      // تجاهل أي أخطاء غير متوقعة هنا
    }
  }

  static Future<int> insertStudent(Student s) async {
    final db = await database();
    return await db.insert(_table, s.toMapForSqlite());
  }

  static Future<int> updateStudent(Student s) async {
    final db = await database();
    s.updatedAt = DateTime.now().millisecondsSinceEpoch;
    return await db.update(_table, s.toMapForSqlite(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  static Future<int> softDeleteStudent(int id) async {
    final db = await database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
        _table, {'deleted': 1, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteStudentHard(int id) async {
    final db = await database();
    return await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Student>> getAllStudents({bool includeDeleted = false}) async {
    final db = await database();
    final where = includeDeleted ? null : 'deleted = 0';
    final res = await db.query(
      _table,
      where: where,
      orderBy: 'CASE WHEN localId IS NULL THEN 1 ELSE 0 END, localId ASC, id ASC',
    );
    return res.map((e) => Student.fromMapSqlite(e)).toList();
  }

  static Future<List<Student>> searchStudents(String q,
      {String? country, String? grade, int? groupNumber}) async {
    final db = await database();
    final whereClauses = <String>['deleted = 0'];
    final whereArgs = <dynamic>[];

    if (country != null) {
      whereClauses.add('country = ?');
      whereArgs.add(country);
    }
    if (grade != null) {
      whereClauses.add('grade = ?');
      whereArgs.add(grade);
    }
    if (groupNumber != null) {
      whereClauses.add('groupNumber = ?');
      whereArgs.add(groupNumber);
    }

    if (q.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR id = ? OR firebaseId = ?)');
      whereArgs.add('%$q%');
      whereArgs.add(int.tryParse(q) ?? -1);
      whereArgs.add(q);
    }

    final res = await db.query(
      _table,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'CASE WHEN localId IS NULL THEN 1 ELSE 0 END, localId ASC, id ASC',
    );
    return res.map((e) => Student.fromMapSqlite(e)).toList();
  }

  static Future<List<Student>> searchDeletedStudents(String q,
      {String? country, String? grade, int? groupNumber}) async {
    final db = await database();
    final whereClauses = <String>['deleted = 1'];
    final whereArgs = <dynamic>[];

    if (country != null) {
      whereClauses.add('country = ?');
      whereArgs.add(country);
    }
    if (grade != null) {
      whereClauses.add('grade = ?');
      whereArgs.add(grade);
    }
    if (groupNumber != null) {
      whereClauses.add('groupNumber = ?');
      whereArgs.add(groupNumber);
    }

    if (q.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR id = ? OR firebaseId = ?)');
      whereArgs.add('%$q%');
      whereArgs.add(int.tryParse(q) ?? -1);
      whereArgs.add(q);
    }

    final res = await db.query(
      _table,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'CASE WHEN localId IS NULL THEN 1 ELSE 0 END, localId ASC, id ASC',
    );
    return res.map((e) => Student.fromMapSqlite(e)).toList();
  }

  static Future<List<int>> _getUsedLocalIdsForGroup({
    required String country,
    required String grade,
    required int groupNumber,
  }) async {
    final db = await database();
    final res = await db.query(
      _table,
      columns: ['localId'],
      where: 'country = ? AND grade = ? AND groupNumber = ? AND localId IS NOT NULL',
      whereArgs: [country, grade, groupNumber],
    );
    return res
        .map((e) => (e['localId'] as int?) ?? 0)
        .where((v) => v > 0)
        .toList();
  }

  static Future<int> getNextAvailableLocalId({
    required String country,
    required String grade,
    required int groupNumber,
  }) async {
    final used = await _getUsedLocalIdsForGroup(
      country: country,
      grade: grade,
      groupNumber: groupNumber,
    );
    if (used.isEmpty) return 1;
    used.sort();
    int candidate = 1;
    for (final v in used) {
      if (v == candidate) {
        candidate++;
      } else if (v > candidate) {
        break;
      }
    }
    return candidate;
  }

  static Future<List<int>> listAvailableLocalIds({
    required String country,
    required String grade,
    required int groupNumber,
  }) async {
    final used = await _getUsedLocalIdsForGroup(
      country: country,
      grade: grade,
      groupNumber: groupNumber,
    );
    if (used.isEmpty) return const [1];
    used.sort();
    final Set<int> usedSet = used.toSet();
    final List<int> free = [];
    final int maxVal = used.isNotEmpty ? used.last : 0;
    for (int i = 1; i <= maxVal; i++) {
      if (!usedSet.contains(i)) free.add(i);
    }
    free.add(maxVal + 1); // include next new id as a suggestion
    return free;
  }

  static Future<bool> isLocalIdAvailable({
    required String country,
    required String grade,
    required int groupNumber,
    required int localId,
  }) async {
    final db = await database();
    final res = await db.query(
      _table,
      columns: ['id'],
      where: 'country = ? AND grade = ? AND groupNumber = ? AND localId = ?',
      whereArgs: [country, grade, groupNumber, localId],
      limit: 1,
    );
    return res.isEmpty;
  }

  static Future<int> restoreStudent(int id) async {
    final db = await database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      _table,
      {'deleted': 0, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<Student>> getUnsyncedItems() async {
    final db = await database();
    final res = await db.query(
      _table,
      where: 'firebaseId = ? OR deleted = 1',
      whereArgs: [''],
    );
    return res.map((e) => Student.fromMapSqlite(e)).toList();
  }

  static Future<Student?> getByFirebaseId(String firebaseId) async {
    final db = await database();
    final res = await db.query(_table,
        where: 'firebaseId = ?', whereArgs: [firebaseId], limit: 1);
    if (res.isEmpty) return null;
    return Student.fromMapSqlite(res.first);
  }

  static Future<void> upsertFromServer(Student s) async {
    final db = await database();
    if (s.firebaseId.isEmpty) return;
    final existing = await getByFirebaseId(s.firebaseId);
    if (existing == null) {
      await db.insert(_table, s.toMapForSqlite());
    } else {
      if (s.updatedAt >= existing.updatedAt) {
        await db.update(_table, s.toMapForSqlite(),
            where: 'firebaseId = ?', whereArgs: [s.firebaseId]);
      }
    }
  }

  static Future<void> updateFirebaseIdForLocal(
      int localId, String firebaseId) async {
    final db = await database();
    await db.update(_table, {'firebaseId': firebaseId},
        where: 'id = ?', whereArgs: [localId]);
  }
}
