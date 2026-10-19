import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/data/state_requirements.dart';
import 'package:license_logger/models/lesson.dart';
import 'package:license_logger/services/test_ready.dart';

void main() {
  test('catalog covers 50 states plus DC', () {
    expect(StateRequirement.all, hasLength(51));
    expect(StateRequirement.byName('CA')?.name, 'California');
    expect(StateRequirement.byName('California')?.practiceHours, 50);
    expect(StateRequirement.byName('California')?.nightHours, 10);
    expect(StateRequirement.byName('California')?.driverEdRequired, isTrue);
    expect(StateRequirement.byName('Maryland')?.holdDays, 270);
    expect(StateRequirement.byName('Virginia')?.holdDays, 270);
  });

  test('California checklist is 0/N until hours and toggles land', () {
    final ready = TestReady.from(
      settings: AppSettings(
        firstName: 'Ava',
        birthday: DateTime(2010, 6, 15),
        stateName: 'California',
        permitIssued: DateTime(2026, 10, 1),
      ),
      hours: 0,
      nightHours: 0,
      now: DateTime(2026, 10, 17),
    );
    expect(ready.total, 7);
    expect(ready.doneCount, 1);
    expect(ready.fraction, '1/7');
    expect(ready.items.map((i) => i.id).toList(), [
      'age',
      'hold',
      'hours',
      'night',
      'driverEd',
      'written',
      'docs',
    ]);
  });

  test('Arkansas skips hour and night items when the state lists none', () {
    final ready = TestReady.from(
      settings: AppSettings(
        firstName: 'Bo',
        birthday: DateTime(2008, 1, 1),
        stateName: 'Arkansas',
        permitIssued: DateTime(2025, 1, 1),
        writtenTestDone: true,
        documentsReady: true,
      ),
      hours: 0,
      nightHours: 0,
      now: DateTime(2026, 10, 17),
    );
    expect(ready.items.any((i) => i.id == 'hours'), isFalse);
    expect(ready.items.any((i) => i.id == 'night'), isFalse);
    expect(ready.items.any((i) => i.id == 'driverEd'), isFalse);
    expect(ready.doneCount, ready.total);
  });
}
