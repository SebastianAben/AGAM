import 'package:flutter/material.dart';

import 'agam_motion.dart';
import 'agam_theme.dart';

/// The coloured ground of the onboarding: a two-stop gradient with two soft
/// glows. Used for hero blocks so every screen reads as the same product.
class AgamGround extends StatelessWidget {
  const AgamGround({
    super.key,
    required this.child,
    this.colors = const [AgamColors.brandDeep, AgamColors.brand],
    this.radius = AgamRadius.card,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final List<Color> colors;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _Glow(
              diameter: 260,
              color: Colors.white.withValues(alpha: .1),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _Glow(
              diameter: 220,
              color: AgamColors.cyan.withValues(alpha: .16),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class AgamCard extends StatelessWidget {
  const AgamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AgamRadius.card),
      boxShadow: AgamShadows.card,
    ),
    child: child,
  );
}

class AgamIconTile extends StatelessWidget {
  const AgamIconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.background = AgamColors.tint,
    this.foreground = AgamColors.brand,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(icon, size: size * .5, color: foreground),
  );
}

class AgamPill extends StatelessWidget {
  const AgamPill(
    this.label, {
    super.key,
    this.tone = AgamColors.brand,
    this.icon,
    this.solid = false,
  });

  final String label;
  final Color tone;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final foreground = solid ? Colors.white : tone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? tone : tone.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The onboarding CTA: a navy stadium with a soft coloured glow that steps
/// down on press. A disabled button keeps its shape and loses the glow.
class AgamPrimaryButton extends StatelessWidget {
  const AgamPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height = 54,
    this.color = AgamColors.brand,
    this.foreground = Colors.white,
    this.labelMaxLines = 1,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;
  final Color color;
  final Color foreground;
  final int labelMaxLines;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedContainer(
      duration: AgamMotion.duration(context, 200),
      curve: AgamMotion.easeOut,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: enabled ? AgamShadows.glow(color) : const [],
      ),
      child: AgamPressFeedback(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: foreground,
            disabledBackgroundColor: AgamColors.fill,
            disabledForegroundColor: AgamColors.subtle,
            minimumSize: Size.fromHeight(height),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy || icon != null) ...[
                // The glyph morphs in place inside a fixed slot, so a new
                // icon never shifts the label.
                SizedBox.square(
                  dimension: 20,
                  child: AnimatedSwitcher(
                    duration: AgamMotion.duration(context, 200),
                    transitionBuilder: AgamMotion.iconSwap,
                    child: busy
                        ? Padding(
                            key: const ValueKey('busy'),
                            padding: const EdgeInsets.all(1),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          )
                        : Icon(icon, key: ValueKey(icon), size: 20),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                // The row is centred, so the label's width decides where
                // the icon sits. Size only to the incoming label and glide
                // the width, so the icon slides instead of snapping when
                // the outgoing label is removed.
                child: AnimatedSize(
                  duration: AgamMotion.duration(context, 240),
                  curve: AgamMotion.easeOut,
                  child: AnimatedSwitcher(
                    duration: AgamMotion.duration(context, 240),
                    // A changed label fades through: the old word is gone
                    // before the new one appears, so the two never overlap.
                    switchInCurve: const Interval(.5, 1, curve: Curves.easeOut),
                    switchOutCurve: const Interval(.5, 1, curve: Curves.easeIn),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (final child in previous)
                          Positioned.fill(
                            child: OverflowBox(
                              maxWidth: double.infinity,
                              child: child,
                            ),
                          ),
                        ?current,
                      ],
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      maxLines: labelMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet second action: tinted fill, no glow.
class AgamTonalButton extends StatelessWidget {
  const AgamTonalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48,
    this.foreground = AgamColors.brand,
    this.background = AgamColors.fill,
    this.padding = 14,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final Color foreground;
  final Color background;

  /// Horizontal inner padding; rows of three buttons use a tighter value.
  final double padding;

  @override
  Widget build(BuildContext context) => AgamPressFeedback(
    child: FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: AgamColors.fill,
        disabledForegroundColor: AgamColors.subtle,
        minimumSize: Size.fromHeight(height),
        padding: EdgeInsets.symmetric(horizontal: padding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AgamRadius.control),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            SizedBox(width: padding < 14 ? 6 : 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The one "Rute" action used wherever a building or facility can be a
/// destination (F06). Until routing is available it stays tappable but
/// quiet and explains itself, so its place can be reviewed today.
class AgamRouteButton extends StatelessWidget {
  const AgamRouteButton({
    super.key,
    required this.available,
    required this.onPressed,
    this.primary = false,
    this.height,
    this.label = 'Rute',
    this.busy = false,
    this.padding,
  });

  final bool available;
  final VoidCallback? onPressed;
  final bool primary;
  final double? height;
  final String label;
  final bool busy;

  /// Inner padding for the tonal form, for rows of three buttons.
  final double? padding;

  static const unavailableMessage = 'Rute belum tersedia.';

  void _explain(BuildContext context) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(unavailableMessage)));

  @override
  Widget build(BuildContext context) {
    if (available && primary) {
      return AgamPrimaryButton(
        onPressed: onPressed,
        busy: busy,
        height: height ?? 54,
        icon: Icons.directions_rounded,
        label: label,
      );
    }
    return AgamTonalButton(
      onPressed: available ? onPressed : () => _explain(context),
      height: height ?? (primary ? 54 : 48),
      icon: Icons.directions_rounded,
      foreground: available ? AgamColors.brand : AgamColors.subtle,
      padding: padding ?? 14,
      label: label,
    );
  }
}

/// Section heading on the canvas, with an optional trailing note.
class AgamSectionHeader extends StatelessWidget {
  const AgamSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: AgamText.headline)),
        if (trailing != null) Text(trailing!, style: AgamText.caption),
      ],
    ),
  );
}

/// Rows grouped in one white card with hairline dividers between them.
class AgamGroup extends StatelessWidget {
  const AgamGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AgamRadius.card),
      boxShadow: AgamShadows.card,
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                color: AgamColors.line,
              ),
            children[index],
          ],
        ],
      ),
    ),
  );
}

/// A row for [AgamGroup]: icon tile, title, subtitle and a trailing widget.
class AgamListRow extends StatelessWidget {
  const AgamListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBackground = AgamColors.tint,
    this.iconForeground = AgamColors.brand,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconBackground;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            AgamIconTile(
              icon: icon,
              size: 42,
              background: iconBackground,
              foreground: iconForeground,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AgamText.label.copyWith(fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AgamText.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    ),
  );
}

/// Segments share one track; the white thumb slides to the chosen segment
/// so the change reads as one movement instead of two colour swaps.
class AgamSegmented extends StatelessWidget {
  const AgamSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AgamColors.fill,
      borderRadius: BorderRadius.circular(23),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / labels.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: AgamMotion.duration(context, 300),
              curve: AgamMotion.drawer,
              left: width * selected,
              top: 0,
              bottom: 0,
              width: width,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140B1F44),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: index == selected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(index),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AgamMotion.duration(context, 180),
                            style: TextStyle(
                              fontFamily: DefaultTextStyle.of(context)
                                  .style
                                  .fontFamily,
                              color: index == selected
                                  ? AgamColors.ink
                                  : AgamColors.muted,
                              fontSize: 13,
                              fontWeight: index == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// A round back control for pages drawn edge to edge. It wraps [BackButton]
/// so it keeps the platform tooltip and semantics.
class AgamBackButton extends StatelessWidget {
  const AgamBackButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: .18) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: onDark ? const [] : AgamShadows.card,
      ),
      child: BackButton(color: onDark ? Colors.white : AgamColors.ink),
    ),
  );
}
