import 'package:flutter/material.dart';

/// A modern outlined tile styled after variation 5 (`V5Outlined`)
/// from `tile_separator_lab_screen.dart`.
///
/// Features:
/// - Rounded rectangular outline container with adaptive border & elevation.
/// - Integrated leading slot (designed for [BookmarkButton] or [AppTileLeadingIcon]).
/// - Bold title typography matching `titleMedium`.
/// - Circular trailing action indicator with smooth hover/press transitions.
/// - Consistent 6px spacing between adjacent tiles when default margin is used.
class AppTile extends StatefulWidget {
  const AppTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    this.padding = const EdgeInsets.fromLTRB(14, 10, 10, 10),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.maxTitleLines = 1,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final int? maxTitleLines;

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.primary;

    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _active
                  ? accent.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: _active ? 0.12 : 0.05),
                blurRadius: _active ? 16 : 6,
                offset: Offset(0, _active ? 6 : 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: widget.borderRadius,
              onHighlightChanged: (highlighted) =>
                  setState(() => _pressed = highlighted),
              onTap: widget.onTap,
              child: Padding(
                padding: widget.padding,
                child: Row(
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: widget.maxTitleLines,
                            overflow: widget.maxTitleLines != null
                                ? TextOverflow.ellipsis
                                : null,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    widget.trailing ??
                        Icon(
                          Icons.chevron_right,
                          color: _active
                              ? accent
                              : scheme.surfaceTint.withValues(alpha: .55),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Companion leading icon container matching the 42x42 dimensions and 13px
/// border radius of [BookmarkButton], for non-bookmark tiles (e.g. today's zikrs).
class AppTileLeadingIcon extends StatelessWidget {
  const AppTileLeadingIcon({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = 20,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: backgroundColor ?? scheme.surfaceContainerHighest,
      ),
      child: Icon(
        icon,
        size: size,
        color: color ?? scheme.primary,
      ),
    );
  }
}
