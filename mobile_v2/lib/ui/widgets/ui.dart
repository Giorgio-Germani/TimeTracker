import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Grouped inset list — the backbone of the iOS look.
class Group extends StatelessWidget {
  const Group({super.key, this.children = const [], this.padding, this.child});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: surface(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: child ?? Column(children: children),
      ),
    );
  }
}

class GRow extends StatelessWidget {
  const GRow({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: sep(context), width: .5)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: DefaultTextStyle.merge(
                style: style.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: destructive ? T.red : ink(context),
                ),
                child: child,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class Chev extends StatelessWidget {
  const Chev({super.key});
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.chevron_right, color: T.tertiary, size: 22);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.top = 22});
  final String text;
  final double top;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, top, 20, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sub(context),
            letterSpacing: .4,
          ),
        ),
      );
}

class ChipTag extends StatelessWidget {
  const ChipTag(this.text, {super.key, this.color = ChipColor.gray});
  final String text;
  final ChipColor color;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (color) {
      ChipColor.green => (const Color(0xFFE8F9EE), T.greenDark),
      ChipColor.blue => (T.blueSoft, T.blue),
      ChipColor.gray => (
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFEEEFF1),
          sub(context)
        ),
      ChipColor.red => (const Color(0xFFFFE9E7), T.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

enum ChipColor { green, blue, gray, red }

class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.name, this.size = 30});
  final String name;
  final double size;

  static Color colorFor(String name) {
    const palette = [
      T.blue, T.indigo, T.orange, T.green, T.red, Color(0xFF64D2FF), Color(0xFFBF5AF2),
    ];
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0xFFFF;
    }
    return palette[h % palette.length];
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorFor(name),
          borderRadius: BorderRadius.circular(size * .28),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * .5,
          ),
        ),
      );
}

class PlayGlyph extends StatelessWidget {
  const PlayGlyph({super.key, this.color = T.blue, this.size = 10});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * .8, size),
        painter: _TrianglePainter(color),
      );
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height / 2)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}

/// Primary filled action button.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, this.onTap, this.color});
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? T.blue,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

/// Large nav-bar title screen header.
class LargeHeader extends StatelessWidget {
  const LargeHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                    color: ink(context))),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
