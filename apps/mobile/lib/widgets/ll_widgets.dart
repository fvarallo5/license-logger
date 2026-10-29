import 'package:flutter/material.dart';

import '../format.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

/// Card: 1px border + soft shadow, 18 px radius. `hero` adds the subtle
/// primary/amber corner wash from textures.css (use on ONE card per screen).
class LLCard extends StatelessWidget {
  const LLCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LL.s4),
    this.hero = false,
    this.outline,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool hero;
  final Color? outline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget inner = Padding(padding: padding, child: child);
    if (hero) {
      inner = DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.1, -1.1),
            radius: 1.25,
            colors: [LL.primary.withValues(alpha: .10), LL.primary.withValues(alpha: 0)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.1, 1.1),
              radius: 1.1,
              colors: [LL.accent.withValues(alpha: .13), LL.accent.withValues(alpha: 0)],
            ),
          ),
          child: inner,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: LL.surface,
        borderRadius: BorderRadius.circular(LL.rLg),
        border: Border.all(color: outline ?? LL.border, width: outline != null ? 1.5 : 1),
        boxShadow: LL.shadowMd,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(LL.rLg),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
      ),
    );
  }
}

enum BadgeKind { pass, warn, fail, info, neutral, night, live }

/// Status = color + dot + label (never color alone).
class LLBadge extends StatelessWidget {
  const LLBadge(this.label, {super.key, this.kind = BadgeKind.neutral, this.dot = true, this.icon});
  final String label;
  final BadgeKind kind;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (kind) {
      BadgeKind.pass => (LL.success, LL.successSoft),
      BadgeKind.warn => (LL.warning, LL.warningSoft),
      BadgeKind.fail => (LL.danger, LL.dangerSoft),
      BadgeKind.info => (LL.primary, LL.primarySoft),
      BadgeKind.neutral => (LL.textMuted, LL.surface2),
      BadgeKind.night => (LL.night, LL.night.withValues(alpha: .12)),
      BadgeKind.live => (LL.brandLimeInk, LL.brandLime),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(bg, LL.surface), // opaque, so badges read on maps too
        borderRadius: BorderRadius.circular(LL.rPill),
        border: kind == BadgeKind.neutral ? Border.all(color: LL.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          if (icon == null && dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: llText(LL.fsXs, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

enum BtnKind { primary, secondary, ghost, danger }

class LLButton extends StatelessWidget {
  const LLButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = BtnKind.primary,
    this.icon,
    this.expand = false,
    this.height = 48,
    this.glow = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final IconData? icon;
  final bool expand;
  final double height;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color fg, BorderSide side) = switch (kind) {
      BtnKind.primary => (LL.primary, LL.onPrimary, BorderSide.none),
      BtnKind.danger => (LL.danger, LL.onPrimary, BorderSide.none),
      BtnKind.secondary => (LL.surface, LL.text, const BorderSide(color: LL.border)),
      BtnKind.ghost => (Colors.transparent, LL.primary, BorderSide.none),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: LL.s2)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: llText(height >= 52 ? LL.fsMd : LL.fsSm, weight: FontWeight.w600, color: fg),
          ),
        ),
      ],
    );
    return AnimatedOpacity(
      duration: LL.durFast,
      opacity: enabled ? 1 : .45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height >= 52 ? LL.rMd : LL.rSm + 2),
          boxShadow: glow && enabled ? LL.glowPrimary : (kind == BtnKind.ghost ? null : LL.shadowSm),
        ),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height >= 52 ? LL.rMd : LL.rSm + 2),
            side: side,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: LL.s4),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.count});
  final String title;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: llText(LL.fsMd, weight: FontWeight.w600)),
        if (count != null) ...[
          const SizedBox(width: LL.s2),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            height: 20,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: LL.accent, borderRadius: BorderRadius.circular(LL.rPill)),
            child: Text('$count', style: llText(LL.fsXs, weight: FontWeight.w700, numeric: true)),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class LinkText extends StatelessWidget {
  const LinkText(this.label, {super.key, this.onTap, this.chevron = true});
  final String label;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LL.rSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: llText(LL.fsSm, weight: FontWeight.w600, color: LL.primary),
            ),
            if (chevron) const Icon(Icons.chevron_right_rounded, size: 18, color: LL.primary),
          ],
        ),
      ),
    );
  }
}

class LLBar extends StatelessWidget {
  const LLBar({super.key, required this.value, required this.max, this.color = LL.primary, this.height = 8});
  final double value;
  final double max;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = (value / max).clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: LL.surface2,
        borderRadius: BorderRadius.circular(LL.rPill),
        border: Border.all(color: LL.border, width: .5),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(LL.rPill)),
          ),
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 32, this.color = LL.primary});
  final String initials;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: .13), LL.surface),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(
        initials,
        style: llText(size * .36, weight: FontWeight.w600, color: color, letterSpacing: 0),
      ),
    );
  }
}

/// The "LL" brand mark (lime square from the portal).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.label = 'LL'});
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LL.brandLime,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [const BoxShadow(color: Color(0x1A0F1B2D), spreadRadius: 1)],
      ),
      child: Text(
        label,
        style: llText(size * .38, weight: FontWeight.w700, color: LL.brandLimeInk, letterSpacing: -.3),
      ),
    );
  }
}

/// Top bar used on tab roots: brand mark, optional center widget, person icon.
class LLTopBar extends StatelessWidget {
  const LLTopBar({super.key, this.center, this.trailing});
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(LL.s4, LL.s2, LL.s4, LL.s2),
      child: Row(
        children: [
          const BrandMark(),
          const SizedBox(width: LL.s3),
          Expanded(child: center ?? const SizedBox()),
          ?trailing,
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton(this.icon, {super.key, this.onTap, this.dot = false, this.size = 40});
  final IconData icon;
  final VoidCallback? onTap;
  final bool dot;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: LL.surface,
          shape: const CircleBorder(side: BorderSide(color: LL.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: 20, color: LL.text),
            ),
          ),
        ),
        if (dot)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: LL.danger,
                shape: BoxShape.circle,
                border: Border.all(color: LL.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.label, required this.value, this.unit, this.sub});
  final String label;
  final String value;
  final String? unit;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: llLabel()),
        const SizedBox(height: LL.s1),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: llText(LL.fsXl, weight: FontWeight.w600, numeric: true),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: llText(LL.fsSm, weight: FontWeight.w500, color: LL.textMuted),
                ),
            ],
          ),
        ),
        if (sub != null) Text(sub!, style: llText(LL.fsXs, color: LL.textMuted)),
      ],
    );
  }
}

class LLChip extends StatelessWidget {
  const LLChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LL.surface2,
        borderRadius: BorderRadius.circular(LL.rSm),
        border: Border.all(color: LL.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: LL.textMuted), const SizedBox(width: 5)],
          Text(label, style: llText(LL.fsXs + 1, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// One saved drive in a list.
class DriveRow extends StatelessWidget {
  const DriveRow({super.key, required this.lesson, this.onTap, this.trailing, this.showDivider = true});
  final Lesson lesson;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final d = lesson;
    final instruction = d.kind == DriveKind.instruction;
    final night = d.nightHours > 0;
    final minutes = (d.creditedSeconds / 60).round();
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: LL.s3),
        decoration: BoxDecoration(
          border: showDivider ? const Border(top: BorderSide(color: LL.border)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: instruction ? LL.successSoft : LL.accentSoft,
                  borderRadius: BorderRadius.circular(LL.rSm),
                  border: Border.all(color: LL.border),
                ),
                child: Icon(
                  instruction ? Icons.school_outlined : Icons.directions_car_outlined,
                  color: instruction ? LL.success : LL.text,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: LL.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          d.isOpen
                              ? 'Driving now'
                              : instruction
                                  ? 'Lesson · ${fmtDate(d.start)}'
                                  : fmtDate(d.start),
                          overflow: TextOverflow.ellipsis,
                          style: llText(LL.fsSm + 1, weight: FontWeight.w600),
                        ),
                      ),
                      if (night) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.nightlight_round, size: 14, color: LL.night),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMinutesHm(minutes)} · ${d.miles.toStringAsFixed(1)} mi',
                    style: llText(LL.fsXs + 1, color: LL.textMuted, numeric: true),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: LL.s2),
            trailing ??
                (instruction
                    ? const LLBadge('Lesson', kind: BadgeKind.info)
                    : d.isOpen
                        ? const LLBadge('Live', kind: BadgeKind.live)
                        : const LLBadge('Logged', kind: BadgeKind.pass)),
          ],
        ),
      ),
    );
  }
}

/// Lightweight page header for pushed screens (back + title + actions).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(LL.s2, LL.s1, LL.s4, LL.s2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: LL.text),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: llText(LL.fsLg, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) Text(subtitle!, style: llText(LL.fsXs + 1, color: LL.textMuted, numeric: true)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

void showMockSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
