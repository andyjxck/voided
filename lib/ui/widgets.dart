// Voided — the shared UI kit: chunky buttons, slate panels, game text,
// currency chips and the pause plate. Every screen builds from these so the
// menus, the HUD and the trays all look like one game.
//
// Look: bright, chunky mobile-game UI on a deep Rift-indigo night. Text is
// Fredoka (headings, numbers) and Rubik (labels) with one soft drop shadow,
// never a hard sticker outline. Panels are slate-indigo with a light top
// edge and a soft shadow; buttons are glossy candy faces on a darker lip.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art.dart';

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

const kDisplayFont = 'Fredoka';
const kBodyFont = 'Rubik';

/// One soft drop shadow under game text. (The name is kept for the old call
/// sites; it no longer draws a hard eight-way outline.)
List<Shadow> outline(Color c, [double w = 2]) => [
  Shadow(
    color: c.withValues(alpha: 0.75),
    offset: Offset(0, 0.6 + w * 0.55),
    blurRadius: 0.5 + w * 0.6,
  ),
];

TextStyle display(
  double size, {
  Color color = Colors.white,
  Color stroke = Vx.ink,
  double w = 2,
  double spacing = 0.5,
}) => TextStyle(
  fontFamily: kDisplayFont,
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: color,
  height: 1.05,
  letterSpacing: spacing * 0.6,
  shadows: w > 0 ? outline(stroke, w) : null,
);

TextStyle body(
  double size, {
  Color color = Vx.text,
  FontWeight weight = FontWeight.w800,
  double height = 1.25,
}) => TextStyle(
  fontFamily: kBodyFont,
  fontSize: size,
  color: color,
  // Rubik ships at 500, 700 and 800: the old heavy weights read as 700.
  fontWeight: weight.value >= 800
      ? FontWeight.w700
      : (weight.value >= 600 ? FontWeight.w500 : weight),
  height: height,
);

// ---------------------------------------------------------------------------
// Palette for the menus and HUD
// ---------------------------------------------------------------------------

class Vx {
  static const ink = Color(0xFF15132E); // thin edges and text shadows
  static const text = Color(0xFFF4F1FF);
  static const textDim = Color(0xFFB7B1D6);
  static const panelTop = Color(0xFF3A4170); // slate-indigo
  static const panelBottom = Color(0xFF272C52);
  static const well = Color(0xFF1D2144);
  static const wellDeep = Color(0xFF151834);
  static const bgTop = Color(0xFF2B2560);
  static const bgBottom = Color(0xFF0E0C24);
  static const gold = Color(0xFFFFC94A);
  static const glass = Color(0xFF7FE3F2); // rift cyan
  static const rift = Color(0xFF9B7BFF); // rift violet
}

/// Button colours: face top, face bottom, lip (the 3D edge) and text shadow.
enum Tone {
  yellow(Color(0xFFFFDD6B), Color(0xFFF5A623), Color(0xFFB0640E)),
  green(Color(0xFF8BEA7B), Color(0xFF3CB44E), Color(0xFF1F7A32)),
  blue(Color(0xFF74CFFF), Color(0xFF2E8FEA), Color(0xFF1B57A6)),
  red(Color(0xFFFF9480), Color(0xFFE6464F), Color(0xFF9C2232)),
  purple(Color(0xFFC9A6FF), Color(0xFF8A5CF0), Color(0xFF5634A8)),
  teal(Color(0xFF7DEBDD), Color(0xFF1FB5A6), Color(0xFF117A70)),
  grey(Color(0xFFC6CADB), Color(0xFF8C92A8), Color(0xFF585D74));

  final Color top;
  final Color bottom;
  final Color lip;
  const Tone(this.top, this.bottom, this.lip);

  /// The thin edge round the face: the lip, a shade darker.
  Color get edge => Color.lerp(lip, const Color(0xFF0B0A1C), 0.35)!;
}

Tone toneForTier(int tier) => const [
  Tone.grey,
  Tone.blue,
  Tone.purple,
  Tone.yellow,
  Tone.red,
][tier.clamp(0, 4)];

// ---------------------------------------------------------------------------
// Backdrops and frames
// ---------------------------------------------------------------------------

/// The night behind every screen: deep indigo with a soft violet glow where
/// the Rift is, and a cooler glow low down. Painted, not a photo, so the
/// board and the buttons are the brightest things on screen.
class SeaBackdrop extends StatelessWidget {
  final Widget child;
  const SeaBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _NightPainter(), child: child);
}

class _NightPainter extends CustomPainter {
  const _NightPainter();
  @override
  void paint(Canvas c, Size size) {
    final r = Offset.zero & size;
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Vx.bgTop, Color(0xFF1B1842), Vx.bgBottom],
          stops: [0, 0.55, 1],
        ).createShader(r),
    );
    final m = math.max(size.width, size.height);
    void glow(Offset at, double rad, Color col) {
      final g = Rect.fromCircle(center: at, radius: rad);
      c.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)])
              .createShader(g),
      );
    }

    glow(
      Offset(size.width / 2, size.height * 0.48),
      m * 0.55,
      const Color(0x386E4BE0),
    );
    glow(
      Offset(size.width * 0.5, size.height * 1.05),
      m * 0.5,
      const Color(0x2242C8E0),
    );
  }

  @override
  bool shouldRepaint(covariant _NightPainter oldDelegate) => false;
}

/// The slate panel used for cards and the pause plate.
class GamePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final List<Color>? colors;
  final double radius;
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.colors,
    this.radius = 18,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFF0D0C22), width: 1.5),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors ?? const [Vx.panelTop, Vx.panelBottom],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x8008061A),
          offset: Offset(0, 6),
          blurRadius: 14,
        ),
      ],
    ),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius - 1.5),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
      ),
      padding: padding,
      child: child,
    ),
  );
}

/// A recessed area inside a panel.
class Well extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;
  const Well({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.color,
    this.border,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Vx.well,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border ?? const Color(0x5510203F), width: 2),
    ),
    child: child,
  );
}

/// A title plate that sits on the top edge of a panel.
class Ribbon extends StatelessWidget {
  final String text;
  final Tone tone;
  const Ribbon(this.text, {super.key, this.tone = Tone.yellow});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Vx.ink, width: 1.5),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tone.top, tone.bottom],
      ),
      boxShadow: [BoxShadow(color: tone.lip, offset: const Offset(0, 4))],
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: display(22, stroke: tone.lip, w: 2.2),
    ),
  );
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

/// The chunky 3D button: a coloured face on a darker lip that sinks when you
/// press it.
class Chunky extends StatefulWidget {
  final Tone tone;
  final VoidCallback? onTap;
  final Widget child;
  final double? width;
  final double height;
  final double radius;
  final String? semantics;
  final bool enabled;
  final EdgeInsets padding;
  const Chunky({
    super.key,
    required this.child,
    this.tone = Tone.blue,
    this.onTap,
    this.width,
    this.height = 52,
    this.radius = 16,
    this.semantics,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  /// The common case: one outlined label and an optional small line under it.
  factory Chunky.label(
    String label, {
    Key? key,
    Tone tone = Tone.blue,
    VoidCallback? onTap,
    String? sub,
    double? width,
    double height = 52,
    double size = 20,
    bool enabled = true,
    Widget? leading,
    String? semantics,
  }) => Chunky(
    key: key,
    tone: tone,
    onTap: onTap,
    width: width,
    height: height,
    enabled: enabled,
    semantics: semantics,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: display(
                  size,
                  stroke: (enabled ? tone : Tone.grey).lip,
                  w: 2,
                ),
              ),
              if (sub != null && sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    sub,
                    style:
                        body(
                          size * 0.55,
                          color: Colors.white,
                          weight: FontWeight.w900,
                        ).copyWith(
                          shadows: outline(
                            (enabled ? tone : Tone.grey).lip,
                            1.2,
                          ),
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  State<Chunky> createState() => _ChunkyState();
}

class _ChunkyState extends State<Chunky> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.enabled ? widget.tone : Tone.grey;
    final lip = _down ? 1.5 : 5.0;
    final r = BorderRadius.circular(widget.radius);
    Widget face = AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      margin: EdgeInsets.only(top: 5 - lip, bottom: lip),
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: t.edge, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.top, t.bottom],
        ),
      ),
      child: Stack(
        children: [
          // Gloss across the top half.
          Positioned(
            left: 5,
            right: 5,
            top: 3,
            height: (widget.height - 10) * 0.36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          Padding(
            padding: widget.padding,
            child: Center(child: widget.child),
          ),
        ],
      ),
    );
    final box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // The lip
          Positioned.fill(
            top: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                color: t.lip,
                border: Border.all(color: t.edge, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6608061A),
                    offset: Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(child: face),
        ],
      ),
    );
    final tappable = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semantics,
      excludeSemantics: widget.semantics != null,
      child: MouseRegion(
        cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: tappable ? (_) => setState(() => _down = true) : null,
          onTapCancel: tappable ? () => setState(() => _down = false) : null,
          onTapUp: tappable ? (_) => setState(() => _down = false) : null,
          onTap: widget.onTap,
          child: Opacity(opacity: widget.enabled ? 1 : 0.75, child: box),
        ),
      ),
    );
  }
}

/// Round close button for dialogs.
class CloseX extends StatelessWidget {
  final VoidCallback onTap;
  const CloseX({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Chunky(
    tone: Tone.red,
    width: 44,
    height: 44,
    radius: 22,
    padding: EdgeInsets.zero,
    semantics: 'Close',
    onTap: onTap,
    child: const Icon(
      Icons.close_rounded,
      color: Colors.white,
      size: 24,
      shadows: [Shadow(color: Vx.ink, offset: Offset(0, 2))],
    ),
  );
}

/// Square icon button with a caption, used on the home screen and in the bar
/// under the pier.
class IconTile extends StatelessWidget {
  final String? sprite;
  final IconData? icon;
  final String label;
  final Tone tone;
  final String? badge;
  final VoidCallback onTap;
  final double size;
  final String? semantics;
  const IconTile({
    super.key,
    this.sprite,
    this.icon,
    required this.label,
    this.tone = Tone.blue,
    this.badge,
    required this.onTap,
    this.size = 64,
    this.semantics,
  });
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Chunky(
        tone: tone,
        width: size,
        height: size + 8,
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
        semantics: semantics ?? label,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: sprite != null
                    ? SpriteImg(sprite!, size: size * 0.52)
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: size * 0.42,
                        shadows: const [
                          Shadow(color: Vx.ink, offset: Offset(0, 2)),
                        ],
                      ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: display(size * 0.2, stroke: tone.lip, w: 1.6),
              ),
            ),
            SizedBox(height: size * 0.06),
          ],
        ),
      ),
      if (badge != null)
        Positioned(
          right: -4,
          top: -6,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              constraints: const BoxConstraints(minWidth: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Vx.ink, width: 1.5),
              ),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: display(13, w: 1.2),
              ),
            ),
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Sprites and chips
// ---------------------------------------------------------------------------

/// A painted sprite from assets/sprites, e.g. 'u_gull', 'i_penny'.
class SpriteImg extends StatelessWidget {
  final String id;
  final double size;
  final bool dim;
  const SpriteImg(this.id, {super.key, required this.size, this.dim = false});
  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      'assets/sprites/$id.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
    if (dim) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFF0E2348),
          BlendMode.srcATop,
        ),
        child: img,
      );
    }
    return ExcludeSemantics(child: img);
  }
}

class CurrencyChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String? sprite;
  const CurrencyChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    this.sprite,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.fromLTRB(2, 0, 10, 0),
    decoration: BoxDecoration(
      color: const Color(0xCC0A1A3A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Vx.ink, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sprite != null)
          SpriteImg(sprite!, size: 26)
        else
          Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(value, style: display(16, w: 1.5)),
      ],
    ),
  );
}

class LaneMeter extends StatelessWidget {
  final int count;
  final int limit;
  const LaneMeter({super.key, required this.count, required this.limit});
  @override
  Widget build(BuildContext context) {
    final f = (count / limit).clamp(0.0, 1.0);
    final col = f < 0.5
        ? const Color(0xFF63E05A)
        : (f < 0.8 ? const Color(0xFFFFC233) : const Color(0xFFFF4D4D));
    return LayoutBuilder(
      builder: (context, c) {
        return Container(
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF0A1A3A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Vx.ink, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: f,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(col, Colors.white, 0.35)!, col],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    c.maxWidth >= 190
                        ? '$count / $limit loose'
                        : '$count / $limit',
                    style: display(12, w: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SpeechBubble extends StatelessWidget {
  final String speaker;
  final String text;
  const SpeechBubble({super.key, required this.speaker, required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Vx.ink, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), offset: Offset(0, 4)),
        ],
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: '$speaker  ',
              style: const TextStyle(
                fontFamily: kDisplayFont,
                color: Color(0xFFD9447A),
                fontSize: 14,
              ),
            ),
            TextSpan(
              text: text,
              style: body(13, color: Vx.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class BigBanner extends StatelessWidget {
  final String title;
  final String sub;
  final double k; // seconds left
  const BigBanner({
    super.key,
    required this.title,
    required this.sub,
    required this.k,
  });
  @override
  Widget build(BuildContext context) {
    final a = k.clamp(0.0, 0.4) / 0.4;
    final scale = 1 + math.max(0, k - 2.0) * 0.5;
    return Opacity(
      opacity: a,
      child: Transform.scale(
        scale: scale.clamp(1.0, 1.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: display(
                  34,
                  color: Vx.gold,
                  stroke: Vx.ink,
                  w: 3,
                  spacing: 1,
                ),
              ),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: display(18, w: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToastPill extends StatelessWidget {
  final String text;
  const ToastPill({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xF20A1A3A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Vx.ink, width: 1.5),
    ),
    child: Text(text, style: body(13, color: Colors.white)),
  );
}

/// Small chunky action used in lists and on the board pop-up.
class ActionBtn extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final Tone? tone;
  final double width;
  const ActionBtn({
    super.key,
    required this.label,
    required this.sub,
    required this.color,
    this.enabled = true,
    required this.onTap,
    this.tone,
    this.width = 84,
  });
  @override
  Widget build(BuildContext context) => Chunky.label(
    label,
    sub: sub,
    tone: tone ?? Tone.blue,
    width: width,
    height: 50,
    size: 16,
    enabled: enabled,
    semantics:
        '$label${sub.isEmpty ? '' : ', $sub'}${enabled ? '' : ', not available'}',
    onTap: enabled ? onTap : null,
  );
}

class SummonButton extends StatelessWidget {
  final int cost;
  final bool enabled;
  final bool glow;
  final VoidCallback onTap;
  const SummonButton({
    super.key,
    required this.cost,
    required this.enabled,
    required this.onTap,
    this.glow = false,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: glow
          ? const [
              BoxShadow(
                color: Color(0xCCFFE15A),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ]
          : null,
    ),
    child: Chunky(
      tone: enabled ? Tone.yellow : Tone.grey,
      height: 74,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      semantics:
          'Summon a figurine, $cost pennies${enabled ? '' : ', not available now'}',
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SUMMON',
              style: display(
                24,
                stroke: (enabled ? Tone.yellow : Tone.grey).lip,
                w: 2.4,
                spacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.fromLTRB(2, 1, 9, 1),
              decoration: BoxDecoration(
                color: const Color(0x55000000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpriteImg('i_penny', size: 18),
                  const SizedBox(width: 3),
                  Text('$cost', style: display(15, w: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Kept for the old call sites: a square tool button with an icon or sprite.
class SmallCtl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  final String? sprite;
  final Tone tone;
  const SmallCtl({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    required this.onTap,
    this.sprite,
    this.tone = Tone.blue,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => IconTile(
      sprite: sprite,
      icon: icon,
      label: label,
      tone: tone,
      badge: badge,
      onTap: onTap,
      size: math.min(66, c.maxWidth.isFinite ? c.maxWidth : 66),
      semantics: badge == null ? label : '$label, $badge',
    ),
  );
}

/// A full-width row button for lists in pop-ups: an optional picture on the
/// left, a title and a line of detail, and a price or arrow on the right.
class WideBtn extends StatelessWidget {
  final String title;
  final String sub;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? leading;
  final String? price;
  final Tone tone;
  const WideBtn({
    super.key,
    required this.title,
    required this.sub,
    required this.color,
    this.enabled = true,
    required this.onTap,
    this.leading,
    this.price,
    this.tone = Tone.blue,
  });
  @override
  Widget build(BuildContext context) => Chunky(
    tone: tone,
    enabled: enabled,
    height: 66,
    padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
    semantics:
        '$title. $sub${price != null ? '. $price' : ''}${enabled ? '' : '. Not available'}',
    onTap: enabled ? onTap : null,
    child: Row(
      children: [
        if (leading != null) ...[
          SizedBox(width: 46, height: 46, child: leading),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: display(
                  16,
                  stroke: (enabled ? tone : Tone.grey).lip,
                  w: 1.6,
                ),
              ),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(11.5, color: Colors.white, weight: FontWeight.w800)
                    .copyWith(
                      shadows: outline((enabled ? tone : Tone.grey).lip, 1),
                    ),
              ),
            ],
          ),
        ),
        if (price != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x44000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(price!, style: display(14, w: 1.4)),
          ),
        ],
      ],
    ),
  );
}

class MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool primary;
  final String? sub;
  final Tone? tone;
  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.primary = false,
    this.sub,
    this.tone,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Chunky.label(
      label,
      sub: sub,
      width: 280,
      height: sub == null ? 54 : 62,
      tone: tone ?? (primary ? Tone.yellow : (danger ? Tone.red : Tone.blue)),
      onTap: onTap,
    ),
  );
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Well(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: display(20, w: 1.6)),
          ),
          const SizedBox(height: 2),
          Text(label, style: body(11, color: Vx.textDim)),
        ],
      ),
    ),
  );
}

/// A determinate bar with a label on it, for album copies and the like.
class ProgressPill extends StatelessWidget {
  final double value;
  final String label;
  final Color color;
  final double height;
  const ProgressPill({
    super.key,
    required this.value,
    required this.label,
    this.color = const Color(0xFF63E05A),
    this.height = 16,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFF0A1A3A),
      borderRadius: BorderRadius.circular(height / 2),
      border: Border.all(color: Vx.ink, width: 1.5),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: color),
          ),
          Center(child: Text(label, style: display(height * 0.68, w: 1.1))),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Pop-up dialogs
// ---------------------------------------------------------------------------

/// The game's pop-up: a framed panel with a title plate and a close button,
/// centred over a dimmed screen.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  double maxWidth = 460,
  Tone tone = Tone.yellow,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $title',
    barrierColor: const Color(0x99050C1E),
    transitionDuration: const Duration(milliseconds: 160),
    transitionBuilder: (_, a, _, child) => Transform.scale(
      scale: 0.9 + 0.1 * Curves.easeOutBack.transform(a.value),
      child: Opacity(opacity: a.value, child: child),
    ),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: MediaQuery.of(ctx).size.height * 0.86,
            ),
            child: GameDialogFrame(
              title: title,
              tone: tone,
              onClose: () => Navigator.of(ctx).maybePop(),
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
  );
}

class GameDialogFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final Tone tone;
  const GameDialogFrame({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.tone = Tone.yellow,
  });
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: GamePanel(
            padding: const EdgeInsets.fromLTRB(12, 34, 12, 14),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              label: title,
              explicitChildNodes: true,
              child: child,
            ),
          ),
        ),
        Positioned(
          left: 50,
          right: 50,
          top: 0,
          child: Center(child: Ribbon(title, tone: tone)),
        ),
        if (onClose != null)
          Positioned(right: -6, top: 10, child: CloseX(onTap: onClose!)),
      ],
    ),
  );
}

/// Screen header for the menu pages: back button, title plate, rift glass.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
    child: Row(
      children: [
        Chunky(
          tone: Tone.blue,
          width: 48,
          height: 48,
          padding: EdgeInsets.zero,
          semantics: 'Back',
          onTap: () => Navigator.of(context).maybePop(),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 26,
            shadows: [Shadow(color: Vx.ink, offset: Offset(0, 2))],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: display(26, w: 2.4),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

// Keep the old palette name reachable from the kit for screens that only
// import widgets.dart.
typedef Palette = Pal;
