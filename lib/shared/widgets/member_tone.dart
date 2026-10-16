import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import 'app_motion.dart';

/// A member's support colour as it reads on this page: the colour itself for
/// dots and bars, a pale wash of it behind a label, and a deeper (or, on a
/// dark page, lighter) shade for words, so a name in 乃琳's blue or 嘉然's
/// pink stays readable at label size.
@immutable
class MemberTone {
  const MemberTone._(this.color, this.wash, this.text);

  factory MemberTone.of(String member, Brightness brightness) {
    final color = AppTheme.memberColors[member] ?? AppTheme.dianaPink;
    final dark = brightness == Brightness.dark;
    return MemberTone._(
      color,
      color.withValues(alpha: dark ? .22 : .15),
      dark
          ? Color.lerp(color, Colors.white, .45)!
          : Color.lerp(color, Colors.black, .38)!,
    );
  }

  final Color color;
  final Color wash;
  final Color text;
}

/// Who appears, as a row of small dots in their colours.
class MemberDots extends StatelessWidget {
  const MemberDots({super.key, required this.members, this.size = 7});
  final List<String> members;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: size * .45,
      children: [
        for (final member in members)
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.memberColors[member] ?? AppTheme.dianaPink,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: size),
          ),
      ],
    ),
  );
}

/// A member's name as a small pill washed in their colour.
class MemberTag extends StatelessWidget {
  const MemberTag({super.key, required this.member, this.label});
  final String member;

  /// What the pill says, when it is not the member's own name ("心宜&思诺").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tone = MemberTone.of(member, Theme.of(context).brightness);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tone.wash,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label ?? member,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: tone.text, height: 1.35),
        ),
      ),
    );
  }
}

/// A vertical (or, with [horizontal], flat) bar split into one segment per
/// member, in their colours; [fallback] fills it when nobody is named.
class MemberBar extends StatelessWidget {
  const MemberBar({
    super.key,
    required this.members,
    required this.fallback,
    this.thickness = 4,
    this.length,
    this.horizontal = false,
  });
  final List<String> members;
  final Color fallback;
  final double thickness;
  final double? length;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final segments = [
      if (members.isEmpty)
        Expanded(child: ColoredBox(color: fallback))
      else
        for (final member in members)
          Expanded(
            child: ColoredBox(color: AppTheme.memberColors[member] ?? fallback),
          ),
    ];
    return SizedBox(
      width: horizontal ? length : thickness,
      height: horizontal ? thickness : length,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(thickness / 2),
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              ),
      ),
    );
  }
}

/// A round avatar with a ring in its member's colour, for posts by a member.
class MemberRing extends StatelessWidget {
  const MemberRing({
    super.key,
    required this.member,
    required this.size,
    required this.child,
  });
  final String? member;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = member == null ? null : AppTheme.memberColors[member];
    if (color == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: child),
    );
  }
}

/// An icon on a small rounded square washed in a member's colour, as a
/// place's mark in a list; with no [member], the page's raised tone.
class ToneBadge extends StatelessWidget {
  const ToneBadge({super.key, required this.icon, this.member, this.size = 32});
  final IconData icon;
  final String? member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = member == null
        ? null
        : MemberTone.of(member!, theme.brightness);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone?.wash ?? theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: SizedBox.square(
          dimension: size,
          // On whole points, so the glyph's strokes stay crisp.
          child: Icon(
            icon,
            size: (size * .56).roundToDouble(),
            color: tone?.text ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A filter strip's member pill, 30px tall; the transparent band around it widens the touch area without
/// making the strip taller to the eye (48 dp on touch platforms).
class MemberQuickChip extends StatelessWidget {
  const MemberQuickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.members = const [],
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Who the chip stands for: a dot each, and, once chosen, a wash of the
  /// first one's colour instead of the generic pink.
  final List<String> members;

  Widget _withDots(Widget label) => members.isEmpty
      ? label
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberDots(members: members, size: 6),
            const SizedBox(width: 6),
            label,
          ],
        );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = appMotion(context, AppTokens.controlMotion);
    final tone = members.isEmpty
        ? null
        : MemberTone.of(members.first, colors.brightness);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: (AppTokens.touchTarget(context) - 30) / 2,
          ),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 30),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected
                  ? tone?.wash ?? colors.primaryContainer
                  : colors.surfaceContainerHigh,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    members.isEmpty ? 12 : 10,
                    5,
                    12,
                    5,
                  ),
                  child: _withDots(
                    AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: AppCurves.standard,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? tone?.text ?? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      child: Text(label),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
