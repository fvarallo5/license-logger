import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/data/hours_calc.dart';
import 'package:license_logger/data/state_rules.dart';

void main() {
  test('parses bundled state_rules.json', () {
    final raw = File('assets/data/state_rules.json').readAsStringSync();
    final repo = StateRulesRepo.fromJsonString(raw);
    expect(repo.jurisdictions.length, 51);
    final ca = repo.byNameOrAbbr('California');
    expect(ca, isNotNull);
    expect(ca!.latest.totalMinutes, 3000);
    final sum = computeHours(const [], ca.latest);
    expect(sum.totalTarget, 3000);
  });
}
