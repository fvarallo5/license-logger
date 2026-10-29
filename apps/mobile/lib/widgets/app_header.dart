import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/settings_sheet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'll_logo.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final live = state.live != null;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: LlLogo(size: 28),
                ),
                const SizedBox(width: 8),
                Text(
                  'LicenseLogger',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: live
                        ? AppColors.accent.withValues(alpha: 0.45)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    state.headerStatus,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: live ? AppColors.text : scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => showSettingsSheet(context),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
