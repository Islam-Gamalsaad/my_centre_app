import 'dart:convert';

class Student {
  int? id; // SQLite autoinc
  int? localId; // Per-group visible ID starting from 1
  String firebaseId; // kept for backward-compatibility of local schema
  String name;
  String country;
  String grade;
  int groupNumber;
  Map<String, int> absence;    // {"9":0,"10":0,...,"6":0}
  Map<String, int> fees;       // نفس الشكل
  Map<String, int> forgetCard; // نفس الشكل
  int updatedAt; // millisSinceEpoch
  bool deleted;  // soft delete flag

  Student({
    this.id,
    this.localId,
    this.firebaseId = '',
    required this.name,
    required this.country,
    required this.grade,
    required this.groupNumber,
    Map<String, int>? absence,
    Map<String, int>? fees,
    Map<String, int>? forgetCard,
    int? updatedAt,
    this.deleted = false,
  })  : absence = absence ?? _defaultMonths(),
        fees = fees ?? _defaultMonths(),
        forgetCard = forgetCard ?? _defaultMonths(),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  static Map<String, int> _defaultMonths() {
    return {
      "9": 0, "10": 0, "11": 0, "12": 0,
      "1": 0, "2": 0, "3": 0, "4": 0,
      "5": 0, "6": 0
    };
  }

  // SQLite map (using JSON text for maps)
  Map<String, dynamic> toMapForSqlite() {
    return {
      'localId': localId,
      'firebaseId': firebaseId,
      'name': name,
      'country': country,
      'grade': grade,
      'groupNumber': groupNumber,
      'absence': jsonEncode(absence),
      'fees': jsonEncode(fees),
      'forgetCard': jsonEncode(forgetCard),
      'updatedAt': updatedAt,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Student.fromMapSqlite(Map<String, dynamic> m) {
    Map<String, int> safeDecode(String? jsonString) {
      if (jsonString == null || jsonString.isEmpty) return _defaultMonths();
      try {
        return Map<String, int>.from(jsonDecode(jsonString));
      } catch (_) {
        return _defaultMonths();
      }
    }

    return Student(
      id: m['id'] as int?,
      localId: m['localId'] as int?,
      firebaseId: m['firebaseId'] ?? '',
      name: m['name'] ?? '',
      country: m['country'] ?? '',
      grade: m['grade'] ?? '',
      groupNumber: m['groupNumber'] ?? 0,
      absence: safeDecode(m['absence']),
      fees: safeDecode(m['fees']),
      forgetCard: safeDecode(m['forgetCard']),
      updatedAt: m['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      deleted: (m['deleted'] ?? 0) == 1,
    );
  }

  // Firestore methods removed since app is offline-only now
}
