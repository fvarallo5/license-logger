import '../services/hour_credit.dart';
import 'geo_point.dart';

enum LessonStatus { scheduled, inLesson, done, noShow }

enum LessonSeat { student, instructor }

/// Practice = permit hours with a licensed adult. Instruction = driving school.
enum DriveKind { practice, instruction }

class Lesson {
  const Lesson({
    required this.id,
    required this.start,
    this.end,
    this.durationSeconds = 0,
    this.nightSeconds = 0,
    this.miles = 0,
    this.meet = '',
    this.notes = '',
    this.status = LessonStatus.done,
    this.autoStarted = false,
    this.autoEnded = false,
    this.kind = DriveKind.practice,
    this.route = const [],
  });

  final String id;
  final DateTime start;
  final DateTime? end;
  final int durationSeconds;
  final int nightSeconds;
  final double miles;
  final String meet;
  final String notes;
  final LessonStatus status;
  final bool autoStarted;
  final bool autoEnded;
  final DriveKind kind;
  final List<GeoPoint> route;

  bool get hasMapGeometry => route.length >= 2;

  int get creditedSeconds => HourCredit.creditedSeconds(
        durationSeconds: durationSeconds,
        miles: miles,
      );

  int get creditedNightSeconds => HourCredit.creditedNightSeconds(
        durationSeconds: durationSeconds,
        nightSeconds: nightSeconds,
        miles: miles,
      );

  /// Permit hours: wall clock capped at miles / 15 mph.
  double get hours => creditedSeconds / 3600;
  double get nightHours => creditedNightSeconds / 3600;
  double get dayHours =>
      ((creditedSeconds - creditedNightSeconds).clamp(0, creditedSeconds)) / 3600;
  double get elapsedHours => durationSeconds / 3600;

  bool get isOpen => status == LessonStatus.inLesson && end == null;

  Lesson copyWith({
    DateTime? end,
    int? durationSeconds,
    int? nightSeconds,
    double? miles,
    String? meet,
    String? notes,
    LessonStatus? status,
    bool? autoStarted,
    bool? autoEnded,
    DriveKind? kind,
    List<GeoPoint>? route,
  }) {
    return Lesson(
      id: id,
      start: start,
      end: end ?? this.end,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      nightSeconds: nightSeconds ?? this.nightSeconds,
      miles: miles ?? this.miles,
      meet: meet ?? this.meet,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      autoStarted: autoStarted ?? this.autoStarted,
      autoEnded: autoEnded ?? this.autoEnded,
      kind: kind ?? this.kind,
      route: route ?? this.route,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'durationSeconds': durationSeconds,
        'nightSeconds': nightSeconds,
        'miles': miles,
        'meet': meet,
        'notes': notes,
        'status': status.name,
        'autoStarted': autoStarted,
        'autoEnded': autoEnded,
        'kind': kind.name,
        'route': route.map((p) => p.toJson()).toList(),
      };

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      nightSeconds: (json['nightSeconds'] as num?)?.toInt() ?? 0,
      miles: (json['miles'] as num?)?.toDouble() ?? 0,
      meet: json['meet'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: LessonStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => LessonStatus.done,
      ),
      autoStarted: json['autoStarted'] == true,
      autoEnded: json['autoEnded'] == true,
      kind: DriveKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => DriveKind.practice,
      ),
      route: (json['route'] as List?)
              ?.map(GeoPoint.fromJson)
              .toList(growable: false) ??
          const [],
    );
  }
}

class AppSettings {
  const AppSettings({
    this.firstName = '',
    this.lastName = '',
    this.birthday,
    this.stateName = '',
    this.permitIssued,
    this.driverEdDone = false,
    this.writtenTestDone = false,
    this.documentsReady = false,
    this.seat = LessonSeat.student,
    this.hourGoal = 50,
    this.nightGoal = 10,
    this.nightStartsMinutes = 18 * 60,
    this.nightEndsMinutes = 6 * 60,
    this.autoDetect = true,
  });

  final String firstName;
  final String lastName;
  final DateTime? birthday;
  final String stateName;
  final DateTime? permitIssued;
  final bool driverEdDone;
  final bool writtenTestDone;
  final bool documentsReady;
  final LessonSeat seat;
  final double hourGoal;
  final double nightGoal;
  final int nightStartsMinutes;
  final int nightEndsMinutes;
  final bool autoDetect;

  String get displayName {
    final n = '$firstName $lastName'.trim();
    return n;
  }

  bool get profileReady =>
      firstName.trim().isNotEmpty && birthday != null && stateName.trim().isNotEmpty;

  int? get ageYears {
    if (birthday == null) return null;
    final now = DateTime.now();
    var years = now.year - birthday!.year;
    final reached = now.month > birthday!.month ||
        (now.month == birthday!.month && now.day >= birthday!.day);
    if (!reached) years--;
    return years;
  }

  AppSettings copyWith({
    String? firstName,
    String? lastName,
    DateTime? birthday,
    String? stateName,
    DateTime? permitIssued,
    bool clearPermitIssued = false,
    bool? driverEdDone,
    bool? writtenTestDone,
    bool? documentsReady,
    LessonSeat? seat,
    double? hourGoal,
    double? nightGoal,
    int? nightStartsMinutes,
    int? nightEndsMinutes,
    bool? autoDetect,
  }) {
    return AppSettings(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthday: birthday ?? this.birthday,
      stateName: stateName ?? this.stateName,
      permitIssued: clearPermitIssued ? null : (permitIssued ?? this.permitIssued),
      driverEdDone: driverEdDone ?? this.driverEdDone,
      writtenTestDone: writtenTestDone ?? this.writtenTestDone,
      documentsReady: documentsReady ?? this.documentsReady,
      seat: seat ?? this.seat,
      hourGoal: hourGoal ?? this.hourGoal,
      nightGoal: nightGoal ?? this.nightGoal,
      nightStartsMinutes: nightStartsMinutes ?? this.nightStartsMinutes,
      nightEndsMinutes: nightEndsMinutes ?? this.nightEndsMinutes,
      autoDetect: autoDetect ?? this.autoDetect,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'birthday': birthday?.toIso8601String(),
        'stateName': stateName,
        'permitIssued': permitIssued?.toIso8601String(),
        'driverEdDone': driverEdDone,
        'writtenTestDone': writtenTestDone,
        'documentsReady': documentsReady,
        'seat': seat.name,
        'hourGoal': hourGoal,
        'nightGoal': nightGoal,
        'nightStartsMinutes': nightStartsMinutes,
        'nightEndsMinutes': nightEndsMinutes,
        'autoDetect': autoDetect,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final storedFirst = json['firstName'] as String? ?? '';
    final storedLast = json['lastName'] as String? ?? '';
    final legacy = (json['displayName'] as String? ?? '').trim();
    var first = storedFirst;
    var last = storedLast;
    if (first.isEmpty && legacy.isNotEmpty) {
      final parts = legacy.split(RegExp(r'\s+'));
      first = parts.first;
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    return AppSettings(
      firstName: first,
      lastName: last,
      birthday: _parseDate(json['birthday']),
      stateName: json['stateName'] as String? ?? '',
      permitIssued: _parseDate(json['permitIssued']),
      driverEdDone: json['driverEdDone'] == true,
      writtenTestDone: json['writtenTestDone'] == true,
      documentsReady: json['documentsReady'] == true,
      seat: LessonSeat.values.firstWhere(
        (s) => s.name == json['seat'],
        orElse: () => LessonSeat.student,
      ),
      hourGoal: (json['hourGoal'] as num?)?.toDouble() ?? 50,
      nightGoal: (json['nightGoal'] as num?)?.toDouble() ?? 10,
      nightStartsMinutes: (json['nightStartsMinutes'] as num?)?.toInt() ?? 18 * 60,
      nightEndsMinutes: (json['nightEndsMinutes'] as num?)?.toInt() ?? 6 * 60,
      autoDetect: json['autoDetect'] != false,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
