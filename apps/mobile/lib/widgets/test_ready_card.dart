import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/test_ready.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class TestReadyCard extends StatelessWidget {
  const TestReadyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ready = TestReady.from(
      settings: state.settings,
      hours: state.totalHours,
      nightHours: state.totalNightHours,
    );
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: ready.allDone ? AppColors.success : AppColors.accent,
          width: 1.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ready.allDone ? 'Test ready' : 'To take the test',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ready.allDone ? AppColors.success : AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ready.fraction,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: ready.allDone ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ready.total == 0 ? 0 : ready.doneCount / ready.total,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: ready.allDone ? AppColors.success : AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          for (final item in ready.items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: item.done,
              onChanged: item.toggleable
                  ? (_) => state.toggleChecklist(item.id)
                  : null,
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}
