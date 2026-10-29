import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/data/log_layouts.dart';
import 'package:license_logger/data/state_rules.dart';
import 'package:license_logger/main.dart';
import 'package:license_logger/models/lesson.dart';
import 'package:license_logger/screens/license/license_hub_screen.dart';
import 'package:license_logger/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppState> loaded({AppSettings? settings}) async {
    final state = AppState(
      store: MemoryStore(settings: settings ?? sampleStudent()),
      gps: FakeTripTracker(),
    );
    state.rules = StateRulesRepo.fromJsonString(
      File('assets/data/state_rules.json').readAsStringSync(),
    );
    state.layouts = Layouts.fromJsonString(
      File('assets/data/log_layouts.json').readAsStringSync(),
    );
    await state.load();
    return state;
  }

  testWidgets('Dashboard shows start drive', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    expect(find.text('LicenseLogger'), findsWidgets);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);
    expect(find.text('Start drive'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Drives'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.textContaining('Ava'), findsWidgets);
    expect(find.textContaining('/'), findsWidgets);
  });

  testWidgets('Start drive flips the hero to End drive', (tester) async {
    final state = await loaded();
    await tester.pumpWidget(LicenseLoggerApp(state: state));
    await tester.tap(find.text('Start drive'));
    await tester.pump();
    await tester.pump();
    expect(find.text('End drive'), findsOneWidget);
    expect(find.text('Driving'), findsWidgets);
    state.dispose();
  });

  testWidgets('Home shows state hour progress', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    await tester.pumpAndSettle();
    expect(find.textContaining('of 50 h'), findsWidgets);
  });

  testWidgets('License hub shows the path', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    await tester.tap(find.text('License'));
    await tester.pumpAndSettle();
    expect(find.text('Your path to a license'), findsOneWidget);
    expect(find.textContaining('Supervised practice'), findsOneWidget);
  });

  testWidgets('Generate my filled log opens the preview', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    await tester.tap(find.text('License'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(of: find.byType(LicenseHubScreen), matching: find.byType(ListView)),
      const Offset(0, -2400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Generate my filled log'), findsWidgets);
    await tester.tap(find.text('Generate my filled log').last);
    await tester.pumpAndSettle();
    expect(find.text('Generate my log'), findsOneWidget);
    expect(find.textContaining('Official layout'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('Log a past drive from Dashboard', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    await tester.tap(find.text('Log a past drive').first);
    await tester.pumpAndSettle();
    expect(find.text('Log a past drive'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, '15');
    await tester.tap(find.text('Save drive'));
    await tester.pumpAndSettle();
    expect(find.text('Save drive'), findsNothing);
  });

  testWidgets('Short manual log stays open with too-short copy', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    await tester.tap(find.text('Log a past drive').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save drive'));
    await tester.pump();
    expect(find.text('Save drive'), findsOneWidget);
    expect(find.textContaining('Trip Too Short To Save'), findsOneWidget);
  });

  testWidgets('New user sees profile creation', (tester) async {
    await tester.pumpWidget(
      LicenseLoggerApp(
        state: await loaded(settings: const AppSettings(autoDetect: false)),
      ),
    );
    expect(find.text('Who is driving?'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.text('Let’s drive'), findsOneWidget);
    expect(find.text('Start drive'), findsNothing);
  });

  testWidgets('Month expands the calendar', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    expect(find.text('This week'), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pump();
    expect(find.text('Practice'), findsWidgets);
  });
}
