import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/models/lesson.dart';

void main() {
  test('hours from seconds need miles at 15 mph', () {
    final sitting = Lesson(
      id: '1',
      start: DateTime(2026, 1, 1),
      durationSeconds: 5400,
      nightSeconds: 1800,
    );
    expect(sitting.hours, 0);
    expect(sitting.nightHours, 0);

    final driven = Lesson(
      id: '2',
      start: DateTime(2026, 1, 1),
      durationSeconds: 5400,
      nightSeconds: 1800,
      miles: 30,
    );
    expect(driven.hours, 1.5);
    expect(driven.nightHours, 0.5);
    expect(driven.dayHours, 1.0);
  });

  test('json roundtrip', () {
    final lesson = Lesson(
      id: 'abc',
      start: DateTime.utc(2026, 4, 1, 16),
      end: DateTime.utc(2026, 4, 1, 17, 30),
      durationSeconds: 5400,
      nightSeconds: 0,
      miles: 12.4,
      meet: 'Lot A',
      notes: 'highway',
      status: LessonStatus.done,
      autoStarted: true,
    );
    final copy = Lesson.fromJson(lesson.toJson());
    expect(copy.id, 'abc');
    expect(copy.miles, 12.4);
    expect(copy.meet, 'Lot A');
    expect(copy.autoStarted, isTrue);
    expect(copy.status, LessonStatus.done);
  });

  test('open lesson is inLesson with no end', () {
    final lesson = Lesson(
      id: 'live',
      start: DateTime(2026, 1, 1),
      status: LessonStatus.inLesson,
    );
    expect(lesson.isOpen, isTrue);
  });

  test('settings default auto-detect on and 50h goal', () {
    const s = AppSettings();
    expect(s.autoDetect, isTrue);
    expect(s.hourGoal, 50);
    expect(s.nightGoal, 10);
    expect(s.seat, LessonSeat.student);
    expect(s.profileReady, isFalse);
  });

  test('profileReady needs name, birthday, and state', () {
    final s = AppSettings(
      firstName: 'Ava',
      birthday: DateTime(2010, 6, 15),
      stateName: 'California',
    );
    expect(s.profileReady, isTrue);
    expect(s.displayName, 'Ava');
    expect(s.ageYears, greaterThanOrEqualTo(15));
  });
}
