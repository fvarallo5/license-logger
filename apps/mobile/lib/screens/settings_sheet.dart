import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson.dart';
import '../services/battery_mode.dart';
import '../state/app_state.dart';
import 'profile_screen.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, pad + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Profile'),
              subtitle: Text(
                s.profileReady
                    ? '${s.displayName} · ${s.stateName}'
                    : 'Name, birthday, state',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(editing: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SegmentedButton<LessonSeat>(
              segments: const [
                ButtonSegment(value: LessonSeat.student, label: Text('Permit driver')),
                ButtonSegment(value: LessonSeat.instructor, label: Text('Instructor')),
              ],
              selected: {s.seat},
              onSelectionChanged: (set) => state.updateSettings(s.copyWith(seat: set.first)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-track'),
              subtitle: const Text(
                'Same GPS start/stop as TrekTrack: speed + distance confirm, park, stitch, silence failsafe.',
              ),
              value: s.autoDetect,
              onChanged: (v) => state.updateSettings(s.copyWith(autoDetect: v)),
            ),
            if (!kIsWeb && Platform.isIOS)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vehicle gate'),
                subtitle: Text(state.activity.statusLabel),
                value: state.activity.gateEnabled,
                onChanged: (v) => state.setVehicleGate(v),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Motion & Fitness'),
              subtitle: Text(
                state.activity.hasPermission
                    ? state.activity.activityLabel
                    : 'Needed so auto-track can sleep GPS until you drive',
              ),
              trailing: Icon(
                state.activity.hasPermission ? Icons.check_circle_outline : Icons.chevron_right,
              ),
              onTap: () => state.requestMotionPermission(),
            ),
            const SizedBox(height: 8),
            Text('GPS mode', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<BatteryMode>(
              segments: const [
                ButtonSegment(value: BatteryMode.batterySaver, label: Text('Saver')),
                ButtonSegment(value: BatteryMode.balanced, label: Text('Balanced')),
                ButtonSegment(value: BatteryMode.accuracy, label: Text('Accuracy')),
              ],
              selected: {state.battery.mode},
              onSelectionChanged: (set) => state.setBatteryMode(set.first),
            ),
            const SizedBox(height: 8),
            Text(
              state.battery.mode.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              state.autoDetect.powerStats.summaryLine,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hour goal'),
              trailing: Text('${s.hourGoal.toStringAsFixed(0)} h'),
              onTap: () async {
                final next = await _pickNumber(context, s.hourGoal, 'Hour goal');
                if (next != null) state.updateSettings(s.copyWith(hourGoal: next));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Night hour goal'),
              trailing: Text('${s.nightGoal.toStringAsFixed(0)} h'),
              onTap: () async {
                final next = await _pickNumber(context, s.nightGoal, 'Night goal');
                if (next != null) state.updateSettings(s.copyWith(nightGoal: next));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Night starts'),
              trailing: Text(_fmtMinutes(s.nightStartsMinutes)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: s.nightStartsMinutes ~/ 60, minute: s.nightStartsMinutes % 60),
                );
                if (picked != null) {
                  state.updateSettings(s.copyWith(nightStartsMinutes: picked.hour * 60 + picked.minute));
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Night ends'),
              trailing: Text(_fmtMinutes(s.nightEndsMinutes)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: s.nightEndsMinutes ~/ 60, minute: s.nightEndsMinutes % 60),
                );
                if (picked != null) {
                  state.updateSettings(s.copyWith(nightEndsMinutes: picked.hour * 60 + picked.minute));
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Hours stay on this phone until the school desk is live. UltraForge LLC',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtMinutes(int m) {
    final h = m ~/ 60;
    final min = (m % 60).toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hr = h % 12 == 0 ? 12 : h % 12;
    return '$hr:$min $suffix';
  }
}

Future<double?> _pickNumber(BuildContext context, double current, String label) async {
  final controller = TextEditingController(text: current.toStringAsFixed(0));
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
