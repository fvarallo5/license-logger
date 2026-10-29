import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart';
import '../../screens/hours_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/settings_sheet.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ll_widgets.dart';

/// Me: profile, permit, family practice, settings.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final j = app.jurisdiction;
    final name = s.displayName.isEmpty ? 'Student' : s.displayName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(LL.s4, 0, LL.s4, LL.s6),
      children: [
        LLTopBar(
          center: Text('Me', style: llText(LL.fsLg, weight: FontWeight.w600)),
          trailing: IconButton(
            tooltip: 'Settings',
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
        const SizedBox(height: LL.s2),
        LLCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen(editing: true)),
          ),
          child: Row(
            children: [
              Avatar(app.initials, size: 56),
              const SizedBox(width: LL.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: llText(LL.fsXl, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      s.permitIssued == null
                          ? 'Add the day you got your permit'
                          : 'Permit issued ${fmtDateLong(s.permitIssued!)} · ${j?.stateName ?? s.stateName}',
                      style: llText(LL.fsXs + 1, color: LL.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LL.textMuted),
            ],
          ),
        ),
        const SizedBox(height: LL.s3),
        LLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: LL.successSoft,
                      borderRadius: BorderRadius.circular(LL.rMd),
                    ),
                    child: const Icon(Icons.family_restroom_rounded, color: LL.success),
                  ),
                  const SizedBox(width: LL.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Practicing with family', style: llText(LL.fsMd, weight: FontWeight.w600)),
                        Text(
                          'No driving school linked yet',
                          style: llText(LL.fsXs + 1, color: LL.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LL.s3),
              Text(
                'Everything works without a school: log drives, track your state’s hours, and copy a hours report. '
                'Join-code school linking comes after TestFlight.',
                style: llText(LL.fsSm, color: LL.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: LL.s3),
        LLCard(
          padding: const EdgeInsets.symmetric(horizontal: LL.s4, vertical: LL.s1),
          child: Column(
            children: [
              _Row(Icons.badge_outlined, 'Account type', trailing: 'Student'),
              _Row(
                Icons.ios_share_rounded,
                'Copy hours report',
                onTap: () => copyHoursReport(context, app),
              ),
              _Row(
                Icons.tune_rounded,
                'GPS and auto-track',
                onTap: () => showSettingsSheet(context),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, {this.trailing, this.onTap, this.last = false});
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: last ? null : const Border(bottom: BorderSide(color: LL.border)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: LL.textMuted),
              const SizedBox(width: LL.s3),
              Expanded(
                child: Text(label, style: llText(LL.fsSm + 1, weight: FontWeight.w500)),
              ),
              if (trailing != null) Text(trailing!, style: llText(LL.fsSm, color: LL.textMuted)),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: LL.textMuted),
            ],
          ),
        ),
      );
}
