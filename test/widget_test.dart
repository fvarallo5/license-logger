import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_logger/main.dart';
import 'package:license_logger/models/lesson.dart';
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
    await state.load();
    return state;
  }

  testWidgets('Dashboard shows start drive', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    expect(find.text('LicenseLogger'), findsWidgets);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);
    expect(find.text('Start drive'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Lessons'), findsOneWidget);
    expect(find.text('Hours'), findsOneWidget);
    expect(find.textContaining('Hey Ava'), findsOneWidget);
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

  testWidgets('Hours shows the permit arc', (tester) async {
    await tester.pumpWidget(LicenseLoggerApp(state: await loaded()));
    await tester.tap(find.text('Hours'));
    await tester.pumpAndSettle();
    expect(find.text('Permit hours'), findsOneWidget);
    expect(find.textContaining('/ 50 hrs'), findsOneWidget);
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
