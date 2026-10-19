import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/state_requirements.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ll_logo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.editing = false});

  final bool editing;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  DateTime? _birthday;
  DateTime? _permitIssued;
  String? _stateName;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _first = TextEditingController(text: s.firstName);
    _last = TextEditingController(text: s.lastName);
    _birthday = s.birthday;
    _permitIssued = s.permitIssued;
    _stateName = s.stateName.isEmpty ? null : s.stateName;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool permit}) async {
    final now = DateTime.now();
    final initial = permit
        ? (_permitIssued ?? now)
        : (_birthday ?? DateTime(now.year - 16, now.month, now.day));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: permit ? DateTime(now.year - 20) : DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (permit) {
        _permitIssued = picked;
      } else {
        _birthday = picked;
      }
    });
  }

  Future<void> _save() async {
    final first = _first.text.trim();
    if (first.isEmpty || _birthday == null || _stateName == null) {
      setState(() => _error = 'Name, birthday, and state get you in.');
      return;
    }
    final req = StateRequirement.byName(_stateName!);
    final state = context.read<AppState>();
    final next = state.settings.copyWith(
      firstName: first,
      lastName: _last.text.trim(),
      birthday: _birthday,
      stateName: _stateName,
      permitIssued: _permitIssued,
      clearPermitIssued: _permitIssued == null,
      hourGoal: (req != null && req.practiceHours > 0)
          ? req.practiceHours.toDouble()
          : state.settings.hourGoal,
      nightGoal: (req != null && req.nightHours > 0)
          ? req.nightHours.toDouble()
          : state.settings.nightGoal,
    );
    await state.updateSettings(next);
    if (widget.editing && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final req = _stateName == null ? null : StateRequirement.byName(_stateName!);
    final dateFmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: widget.editing
          ? AppBar(
              title: const Text('Profile'),
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (!widget.editing) ...[
              const Center(child: LlLogo(size: 56)),
              const SizedBox(height: 14),
              const Text(
                'Who is driving?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We load your state’s hour rules so the checklist knows when you can take the test.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 22),
            ],
            TextField(
              controller: _first,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'First name',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Last name',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Birthday'),
              subtitle: Text(
                _birthday == null ? 'Required' : dateFmt.format(_birthday!),
              ),
              trailing: const Icon(Icons.cake_outlined),
              onTap: () => _pickDate(permit: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('State'),
              subtitle: Text(_stateName ?? 'Where you will test'),
              trailing: const Icon(Icons.map_outlined),
              onTap: _pickState,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permit date'),
              subtitle: Text(
                _permitIssued == null
                    ? 'Optional · starts the hold clock'
                    : dateFmt.format(_permitIssued!),
              ),
              trailing: const Icon(Icons.badge_outlined),
              onTap: () => _pickDate(permit: true),
            ),
            if (req != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${req.name} · ${req.abbr}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text('Practice hours: ${req.practiceLabel}'),
                    Text('Night hours: ${req.nightLabel}'),
                    Text('Permit hold: ${req.permitHold}'),
                    Text('Driver ed: ${req.driverEd}'),
                    const SizedBox(height: 6),
                    Text(
                      'Confirm with your DMV — rules change.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _save,
                child: Text(widget.editing ? 'Save profile' : 'Let’s drive'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickState() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: ListView.builder(
            itemCount: StateRequirement.all.length,
            itemBuilder: (context, i) {
              final s = StateRequirement.all[i];
              return ListTile(
                title: Text(s.name),
                subtitle: Text(
                  '${s.practiceHours} h'
                  '${s.nightHours > 0 ? ' · ${s.nightHours} night' : ''}',
                ),
                trailing: Text(s.abbr, style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(context, s.name),
              );
            },
          ),
        );
      },
    );
    if (picked != null) setState(() => _stateName = picked);
  }
}
