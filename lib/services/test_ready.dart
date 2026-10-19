import '../data/state_requirements.dart';
import '../models/lesson.dart';

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.done,
    this.toggleable = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool done;
  final bool toggleable;
}

class TestReady {
  const TestReady(this.items);

  final List<ChecklistItem> items;

  int get doneCount => items.where((i) => i.done).length;
  int get total => items.length;
  bool get allDone => total > 0 && doneCount == total;
  String get fraction => '$doneCount/$total';

  static TestReady from({
    required AppSettings settings,
    required double hours,
    required double nightHours,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final req = StateRequirement.byName(settings.stateName);
    final items = <ChecklistItem>[];

    final age = settings.ageYears;
    items.add(
      ChecklistItem(
        id: 'age',
        title: 'Be 16 for the road test',
        subtitle: age == null
            ? 'Add your birthday'
            : age >= 16
                ? 'You are $age'
                : 'You are $age · most states test at 16',
        done: (age ?? 0) >= 16,
      ),
    );

    if (req == null || req.holdDays > 0) {
      final need = req?.holdDays ?? 180;
      final held = settings.permitIssued == null
          ? 0
          : today.difference(settings.permitIssued!).inDays.clamp(0, 100000);
      items.add(
        ChecklistItem(
          id: 'hold',
          title: 'Hold your permit $need days',
          subtitle: settings.permitIssued == null
              ? 'Add the day you got your permit'
              : '$held / $need days',
          done: settings.permitIssued != null && held >= need,
        ),
      );
    }

    final hourGoal = (req != null && req.practiceHours > 0)
        ? req.practiceHours.toDouble()
        : settings.hourGoal;
    if (req == null || req.practiceHours > 0) {
      items.add(
        ChecklistItem(
          id: 'hours',
          title: 'Log ${hourGoal.toStringAsFixed(0)} practice hours',
          subtitle:
              '${hours.toStringAsFixed(1)} / ${hourGoal.toStringAsFixed(0)} h',
          done: hours + 0.05 >= hourGoal,
        ),
      );
    }

    final nightGoal = (req != null && req.nightHours > 0)
        ? req.nightHours.toDouble()
        : 0;
    if (nightGoal > 0) {
      items.add(
        ChecklistItem(
          id: 'night',
          title: 'Log ${nightGoal.toStringAsFixed(0)} night hours',
          subtitle:
              '${nightHours.toStringAsFixed(1)} / ${nightGoal.toStringAsFixed(0)} h',
          done: nightHours + 0.05 >= nightGoal,
        ),
      );
    }

    if (req == null || req.driverEdRequired) {
      items.add(
        ChecklistItem(
          id: 'driverEd',
          title: 'Finish driver ed',
          subtitle: req?.driverEd ?? 'Required in some states under 18',
          done: settings.driverEdDone,
          toggleable: true,
        ),
      );
    }

    items.add(
      ChecklistItem(
        id: 'written',
        title: 'Pass the written test',
        subtitle: req?.writtenTest ?? 'Required for a permit in most states',
        done: settings.writtenTestDone,
        toggleable: true,
      ),
    );

    items.add(
      ChecklistItem(
        id: 'docs',
        title: 'Pack your documents',
        subtitle: req?.documents ?? 'Birth certificate, SSN, proof of residency',
        done: settings.documentsReady,
        toggleable: true,
      ),
    );

    return TestReady(items);
  }
}
