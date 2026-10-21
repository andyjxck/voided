// Procedural art: figurines, riftlings, bosses. One look throughout: flat
// seaside-souvenir shapes with chunky outlines and googly eyes.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import 'sprites.dart';

class Pal {
  static const sea = Color(0xFF0B1630);
  static const sea2 = Color(0xFF132447);
  static const deck = Color(0xFF6B4A33);
  static const deckDark = Color(0xFF4A3223);
  static const plank = Color(0xFF8A6345);
  static const ink = Color(0xFF141018);
  static const cream = Color(0xFFFFF4DC);
  static const penny = Color(0xFFE8A84A);
  static const leaf = Color(0xFF9BE15D);
  static const danger = Color(0xFFFF5E7E);
  static const panel = Color(0xFF1B1530);
  static const panel2 = Color(0xFF261E42);
  static const neon = Color(0xFFFFD34D);
}

final Map<String, TextPainter> _tpCache = {};

TextPainter tp(
  String s,
  double size,
  Color color, {
  FontWeight w = FontWeight.w800,
  bool shadow = false,
}) {
  final key =
      '$s|${size.toStringAsFixed(1)}|${color.toARGB32()}|${w.value}|$shadow';
  final hit = _tpCache[key];
  if (hit != null) return hit;
  if (_tpCache.length > 600) _tpCache.clear();
  final p = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'Lilita',
        fontSize: size,
        color: color,
        height: 1.0,
        letterSpacing: 0.3,
        shadows: color.a < 0.9
            ? null
            : [
                for (var i = 0; i < 8; i++)
                  Shadow(
                    color: const Color(0xFF10203F),
                    offset:
                        Offset(
                          math.cos(i * math.pi / 4),
                          math.sin(i * math.pi / 4),
                        ) *
                        math.max(1.0, size * 0.09),
                  ),
              ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  _tpCache[key] = p;
  return p;
}

void drawText(
  Canvas c,
  String s,
  Offset center,
  double size,
  Color color, {
  FontWeight w = FontWeight.w800,
  bool shadow = false,
}) {
  final p = tp(s, size, color, w: w);
  p.paint(c, center - Offset(p.width / 2, p.height / 2));
}

Path shapePath(Shape s, Offset c, double r) {
  final p = Path();
  switch (s) {
    case Shape.circle:
      p.addOval(Rect.fromCircle(center: c, radius: r));
    case Shape.square:
      p.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: c, radius: r * 0.88),
          Radius.circular(r * 0.3),
        ),
      );
    case Shape.diamond:
      p.moveTo(c.dx, c.dy - r * 1.05);
      p.lineTo(c.dx + r, c.dy);
      p.lineTo(c.dx, c.dy + r * 1.05);
      p.lineTo(c.dx - r, c.dy);
      p.close();
    case Shape.hexagon:
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 6 + i * math.pi / 3;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
    case Shape.star:
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final rr = i.isEven ? r * 1.08 : r * 0.62;
        final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
    case Shape.triangle:
      p.moveTo(c.dx, c.dy - r * 1.05);
      p.quadraticBezierTo(
        c.dx + r * 0.2,
        c.dy - r * 0.8,
        c.dx + r * 1.0,
        c.dy + r * 0.75,
      );
      p.quadraticBezierTo(
        c.dx,
        c.dy + r * 1.0,
        c.dx - r * 1.0,
        c.dy + r * 0.75,
      );
      p.quadraticBezierTo(
        c.dx - r * 0.2,
        c.dy - r * 0.8,
        c.dx,
        c.dy - r * 1.05,
      );
      p.close();
    case Shape.drop:
      p.moveTo(c.dx, c.dy - r * 1.1);
      p.cubicTo(
        c.dx + r * 0.5,
        c.dy - r * 0.5,
        c.dx + r * 1.0,
        c.dy,
        c.dx + r * 0.9,
        c.dy + r * 0.35,
      );
      p.arcToPoint(
        Offset(c.dx - r * 0.9, c.dy + r * 0.35),
        radius: Radius.circular(r * 0.92),
        clockwise: true,
      );
      p.cubicTo(
        c.dx - r * 1.0,
        c.dy,
        c.dx - r * 0.5,
        c.dy - r * 0.5,
        c.dx,
        c.dy - r * 1.1,
      );
      p.close();
    case Shape.shield:
      p.moveTo(c.dx - r * 0.9, c.dy - r * 0.85);
      p.lineTo(c.dx + r * 0.9, c.dy - r * 0.85);
      p.quadraticBezierTo(
        c.dx + r * 0.95,
        c.dy + r * 0.4,
        c.dx,
        c.dy + r * 1.05,
      );
      p.quadraticBezierTo(
        c.dx - r * 0.95,
        c.dy + r * 0.4,
        c.dx - r * 0.9,
        c.dy - r * 0.85,
      );
      p.close();
  }
  return p;
}

Color _darker(Color c, [double f = 0.35]) => Color.lerp(c, Colors.black, f)!;

void drawEyes(
  Canvas c,
  Offset center,
  double r, {
  double look = 0,
  bool angry = false,
  double blink = 1,
}) {
  final eyeR = r * 0.2;
  final white = Paint()..color = Colors.white;
  final ink = Paint()..color = Pal.ink;
  for (final sx in [-1.0, 1.0]) {
    final e = center + Offset(sx * r * 0.32, -r * 0.18);
    c.drawOval(
      Rect.fromCenter(center: e, width: eyeR * 2, height: eyeR * 2 * blink),
      white,
    );
    c.drawCircle(
      e + Offset(look * eyeR * 0.4, eyeR * 0.15),
      eyeR * 0.55 * blink,
      ink,
    );
    if (angry) {
      final brow = Paint()
        ..color = Pal.ink
        ..strokeWidth = math.max(1, r * 0.09)
        ..strokeCap = StrokeCap.round;
      c.drawLine(
        e + Offset(-sx * eyeR * 1.1, -eyeR * 1.5),
        e + Offset(sx * eyeR * 0.9, -eyeR * 0.9),
        brow,
      );
    }
  }
}

/// A figurine token. [t] is wall-clock seconds for idle animation.
void drawUnit(
  Canvas c,
  Offset center,
  double r,
  UnitDef d,
  double t, {
  bool disabled = false,
  double pop = 1,
  bool showMono = true,
}) {
  final img = Sprites.unit(d.id);
  if (img != null) {
    _drawUnitSprite(c, center, r, d, t, img, disabled: disabled, pop: pop);
    return;
  }
  final tier = Color(d.tier.color);
  final col = Color(d.color);
  final bob = math.sin(t * 2.4 + d.id.hashCode % 7) * r * 0.05;
  final cc = center + Offset(0, bob);
  final rr = r * pop;
  // shadow
  c.drawOval(
    Rect.fromCenter(
      center: center + Offset(0, r * 0.85),
      width: r * 1.6,
      height: r * 0.45,
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );
  // tier halo
  if (d.tier.index >= 3) {
    final glow = Paint()
      ..color = tier.withValues(alpha: 0.55 + 0.25 * math.sin(t * 3))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.45);
    c.drawCircle(cc, rr * 1.1, glow);
  }
  if (d.tier == Tier.mythic) {
    final rays = Paint()..color = tier.withValues(alpha: 0.35);
    for (var i = 0; i < 8; i++) {
      final a = t * 0.8 + i * math.pi / 4;
      final path = Path()
        ..moveTo(cc.dx, cc.dy)
        ..lineTo(
          cc.dx + math.cos(a - 0.12) * rr * 1.7,
          cc.dy + math.sin(a - 0.12) * rr * 1.7,
        )
        ..lineTo(
          cc.dx + math.cos(a + 0.12) * rr * 1.7,
          cc.dy + math.sin(a + 0.12) * rr * 1.7,
        )
        ..close();
      c.drawPath(path, rays);
    }
  }
  // base plinth ring in tier colour
  c.drawCircle(cc, rr, Paint()..color = Pal.ink);
  c.drawCircle(cc, rr * 0.9, Paint()..color = tier);
  c.drawCircle(cc, rr * 0.74, Paint()..color = _darker(tier, 0.55));
  // body
  final body = shapePath(d.shape, cc, rr * 0.66);
  c.drawPath(body, Paint()..color = col);
  c.drawPath(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, rr * 0.08)
      ..color = _darker(col, 0.6),
  );
  // shine
  c.drawCircle(
    cc + Offset(-rr * 0.25, -rr * 0.35),
    rr * 0.12,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
  final blink = ((t + d.id.length) % 4.0) < 0.12 ? 0.15 : 1.0;
  drawEyes(
    c,
    cc + Offset(0, -rr * 0.05),
    rr * 0.66,
    look: math.sin(t + d.id.length),
    blink: blink,
  );
  if (showMono && rr > 9) {
    drawText(
      c,
      d.mono,
      cc + Offset(0, rr * 0.33),
      rr * 0.36,
      _darker(col, 0.75),
    );
  }
  if (disabled) {
    c.drawCircle(cc, rr, Paint()..color = Colors.black.withValues(alpha: 0.55));
  }
}

void drawEnemy(
  Canvas c,
  Offset p,
  double r,
  EnemyDef d,
  double t, {
  double flash = 0,
  bool frozen = false,
}) {
  final img = Sprites.enemy(d.id);
  if (img != null) {
    _drawCritter(
      c,
      p,
      r * 1.15,
      img,
      t,
      flash: flash,
      frozen: frozen,
      waddle: 1,
    );
    return;
  }
  var col = Color(d.color);
  if (flash > 0) col = Color.lerp(col, Colors.white, 0.7)!;
  if (frozen) col = Color.lerp(col, const Color(0xFF9EE7FF), 0.6)!;
  final paint = Paint()..color = col;
  final ink = Paint()
    ..color = _darker(col, 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, r * 0.12);
  final wob = math.sin(t * 8 + p.dx) * 0.06;
  c.drawOval(
    Rect.fromCenter(
      center: p + Offset(0, r * 0.8),
      width: r * 1.6,
      height: r * 0.4,
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.3),
  );
  switch (d.body) {
    case 1: // crab
      for (final sx in [-1.0, 1.0]) {
        final cl = p + Offset(sx * r * 1.05, -r * 0.35);
        c.drawCircle(cl, r * 0.38, paint);
        c.drawCircle(cl, r * 0.38, ink);
      }
      final rect = Rect.fromCenter(
        center: p,
        width: r * 1.9,
        height: r * 1.3 * (1 + wob),
      );
      c.drawOval(rect, paint);
      c.drawOval(rect, ink);
    case 2: // eel / fish
      final path = Path()
        ..addOval(
          Rect.fromCenter(
            center: p,
            width: r * 2.2,
            height: r * 1.2 * (1 + wob),
          ),
        )
        ..moveTo(p.dx - r * 1.0, p.dy)
        ..lineTo(p.dx - r * 1.7, p.dy - r * 0.6)
        ..lineTo(p.dx - r * 1.7, p.dy + r * 0.6)
        ..close();
      c.drawPath(path, paint);
      c.drawPath(path, ink);
    case 3: // jelly
      final tent = Paint()
        ..color = col
        ..strokeWidth = math.max(1, r * 0.15)
        ..strokeCap = StrokeCap.round;
      for (var i = -1; i <= 1; i++) {
        final x = p.dx + i * r * 0.45;
        c.drawLine(
          Offset(x, p.dy + r * 0.2),
          Offset(x + math.sin(t * 6 + i) * r * 0.25, p.dy + r * 1.0),
          tent,
        );
      }
      final dome = Path()
        ..addArc(
          Rect.fromCenter(
            center: p + Offset(0, r * 0.2),
            width: r * 2,
            height: r * 2 * (1 + wob),
          ),
          math.pi,
          math.pi,
        )
        ..close();
      c.drawPath(dome, paint);
      c.drawPath(dome, ink);
    case 4: // kelp nanny
      final frond = Paint()..color = const Color(0xFF7BD389);
      for (var i = 0; i < 3; i++) {
        final a = -math.pi / 2 + (i - 1) * 0.6 + math.sin(t * 3 + i) * 0.15;
        c.drawOval(
          Rect.fromCenter(
            center: p + Offset(math.cos(a), math.sin(a)) * r * 0.95,
            width: r * 0.5,
            height: r * 0.9,
          ),
          frond,
        );
      }
      c.drawCircle(p, r, paint);
      c.drawCircle(p, r, ink);
      c.drawCircle(
        p,
        r * 1.6 + math.sin(t * 4) * r * 0.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x557BD389),
      );
    case 5: // mist
      final m = Paint()..color = col.withValues(alpha: 0.6);
      for (var i = 0; i < 3; i++) {
        c.drawCircle(
          p + Offset((i - 1) * r * 0.6, math.sin(t * 3 + i) * r * 0.15),
          r * 0.7,
          m,
        );
      }
    default: // drip
      final path = shapePath(Shape.drop, p, r * (1 + wob));
      c.drawPath(path, paint);
      c.drawPath(path, ink);
  }
  drawEyes(c, p, r, look: 1, angry: d.body != 5);
}

void drawBoss(
  Canvas c,
  Offset p,
  double r,
  BossDef b,
  double t, {
  double flash = 0,
  bool submerged = false,
  double shield = 0,
}) {
  final img = Sprites.boss(b.id);
  if (img != null) {
    if (submerged) {
      for (var i = 0; i < 3; i++) {
        final rr = r * (0.6 + ((t * 0.8 + i / 3) % 1) * 1.2);
        c.drawOval(
          Rect.fromCenter(
            center: p + Offset(0, r * 0.6),
            width: rr * 2,
            height: rr * 0.8,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFBFF3FF)
                .withValues(alpha: 0.7 * (1 - (rr / (r * 1.8)))),
        );
      }
      _drawCritter(
        c,
        p + Offset(0, r * 0.35),
        r * 1.25,
        img,
        t,
        alpha: 0.28,
        waddle: 0.4,
      );
      return;
    }
    // A warning ring on the boards under the boss.
    c.drawOval(
      Rect.fromCenter(
        center: p + Offset(0, r * 0.95),
        width: r * 2.6,
        height: r * 0.8,
      ),
      Paint()
        ..color = const Color(0xFFFF3B3B)
            .withValues(alpha: 0.18 + 0.1 * math.sin(t * 5)),
    );
    _drawCritter(c, p, r * 1.3, img, t, flash: flash, waddle: 0.5);
    if (shield > 0) {
      c.drawCircle(
        p,
        r * 1.45,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..color = const Color(0xBB9EE7FF),
      );
      c.drawCircle(p, r * 1.45, Paint()..color = const Color(0x229EE7FF));
    }
    return;
  }
  var col = Color(b.color);
  if (flash > 0) col = Color.lerp(col, Colors.white, 0.5)!;
  final alpha = submerged ? 0.25 : 1.0;
  final paint = Paint()..color = col.withValues(alpha: alpha);
  final ink = Paint()
    ..color = _darker(col, 0.65).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(2, r * 0.08);
  final pulse = 1 + math.sin(t * 3) * 0.04;
  c.drawOval(
    Rect.fromCenter(
      center: p + Offset(0, r * 0.85),
      width: r * 1.9,
      height: r * 0.5,
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.35 * alpha),
  );
  if (submerged) {
    for (var i = 0; i < 3; i++) {
      final rr = r * (0.6 + ((t * 0.8 + i / 3) % 1) * 1.2);
      c.drawCircle(
        p,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF9EE7FF)
              .withValues(alpha: 0.5 * (1 - (rr / (r * 1.8)))),
      );
    }
    return;
  }
  switch (b.mech) {
    case BossMech.brood:
      final path = shapePath(Shape.drop, p, r * pulse);
      c.drawPath(path, paint);
      c.drawPath(path, ink);
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.35;
        c.drawCircle(
          p + Offset(math.cos(a), math.sin(a)) * r * 1.15,
          r * 0.14,
          Paint()..color = const Color(0xFFBFF5D8),
        );
      }
      drawEyes(c, p + Offset(0, r * 0.1), r * 0.9, look: 1, angry: true);
    case BossMech.inspector:
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: r * 1.7, height: r * 2.0),
        Radius.circular(r * 0.4),
      );
      c.drawRRect(rect, paint);
      c.drawRRect(rect, ink);
      // flat cap
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: p + Offset(0, -r * 1.05),
            width: r * 1.9,
            height: r * 0.45,
          ),
          Radius.circular(r * 0.2),
        ),
        Paint()..color = const Color(0xFF39404F),
      );
      // clipboard
      final cb = Rect.fromCenter(
        center: p + Offset(r * 0.95, r * 0.4),
        width: r * 0.8,
        height: r * 1.0,
      );
      c.drawRect(cb, Paint()..color = const Color(0xFFE9D8A6));
      c.drawRect(
        cb,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Pal.ink,
      );
      for (var i = 0; i < 3; i++) {
        c.drawLine(
          cb.topLeft + Offset(r * 0.12, r * (0.25 + i * 0.22)),
          cb.topRight + Offset(-r * 0.12, r * (0.25 + i * 0.22)),
          Paint()
            ..color = Pal.ink
            ..strokeWidth = 1.5,
        );
      }
      drawEyes(
        c,
        p + Offset(0, -r * 0.2),
        r * 0.85,
        look: math.sin(t * 2),
        angry: true,
      );
    case BossMech.undertow:
      for (var i = 0; i < 4; i++) {
        final a = t * 2 + i * math.pi / 2;
        c.drawArc(
          Rect.fromCircle(center: p, radius: r * (0.7 + i * 0.12)),
          a,
          2.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.16
            ..color = Color.lerp(col, const Color(0xFF6EC6FF), i / 4)!,
        );
      }
      c.drawCircle(p, r * 0.55, paint);
      drawEyes(c, p, r * 0.6, look: 0, angry: true);
    case BossMech.landlord:
      c.drawOval(
        Rect.fromCenter(center: p, width: r * 2.0 * pulse, height: r * 1.9),
        paint,
      );
      c.drawOval(
        Rect.fromCenter(center: p, width: r * 2.0 * pulse, height: r * 1.9),
        ink,
      );
      // top hat
      final hat = Paint()..color = const Color(0xFF151018);
      c.drawRect(
        Rect.fromCenter(
          center: p + Offset(0, -r * 0.95),
          width: r * 1.7,
          height: r * 0.2,
        ),
        hat,
      );
      c.drawRect(
        Rect.fromCenter(
          center: p + Offset(0, -r * 1.45),
          width: r * 1.05,
          height: r * 0.95,
        ),
        hat,
      );
      c.drawRect(
        Rect.fromCenter(
          center: p + Offset(0, -r * 1.1),
          width: r * 1.05,
          height: r * 0.14,
        ),
        Paint()..color = Pal.danger,
      );
      drawEyes(c, p + Offset(0, -r * 0.1), r * 0.85, look: 1, angry: true);
      // monocle
      c.drawCircle(
        p + Offset(r * 0.27, -r * 0.25),
        r * 0.26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Pal.neon,
      );
      // moustache
      final m = Path()
        ..moveTo(p.dx - r * 0.55, p.dy + r * 0.3)
        ..quadraticBezierTo(
          p.dx,
          p.dy + r * 0.05,
          p.dx + r * 0.55,
          p.dy + r * 0.3,
        )
        ..quadraticBezierTo(
          p.dx,
          p.dy + r * 0.25,
          p.dx - r * 0.55,
          p.dy + r * 0.3,
        );
      c.drawPath(m, hat);
    default:
      // Plan bosses without a drawn fallback: a plain weathered body.
      c.drawCircle(p, r * pulse, paint);
      c.drawCircle(p, r * pulse, ink);
      drawEyes(c, p, r * 0.8, look: 0, angry: true);
  }
  if (shield > 0) {
    c.drawCircle(
      p,
      r * 1.35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0xAA9EE7FF),
    );
  }
}

Rect _fit(ui.Image img, Offset bottomCentre, double h, double maxW) {
  var w = h * img.width / img.height;
  var hh = h;
  if (w > maxW) {
    hh = h * maxW / w;
    w = maxW;
  }
  return Rect.fromLTWH(bottomCentre.dx - w / 2, bottomCentre.dy - hh, w, hh);
}

/// A figurine standing on its tier-coloured game-piece base.
void _drawUnitSprite(
  Canvas c,
  Offset center,
  double r,
  UnitDef d,
  double t,
  ui.Image img, {
  bool disabled = false,
  double pop = 1,
}) {
  final tier = Color(d.tier.color);
  final rr = r * pop;
  final baseC = center + Offset(0, r * 0.62);
  // Glow for the big tiers.
  if (d.tier.index >= 3) {
    c.drawOval(
      Rect.fromCenter(center: center, width: rr * 2.6, height: rr * 2.6),
      Paint()
        ..color = tier.withValues(alpha: 0.35 + 0.15 * math.sin(t * 3))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.5),
    );
  }
  // Base: shadow, rim, top.
  final bw = rr * 1.75, bh = rr * 0.62;
  c.drawOval(
    Rect.fromCenter(
      center: baseC + Offset(0, bh * 0.28),
      width: bw * 1.04,
      height: bh * 1.05,
    ),
    Paint()..color = const Color(0x55000000),
  );
  c.drawOval(
    Rect.fromCenter(
      center: baseC + Offset(0, bh * 0.16),
      width: bw,
      height: bh,
    ),
    Paint()..color = Pal.ink,
  );
  c.drawOval(
    Rect.fromCenter(
      center: baseC + Offset(0, bh * 0.1),
      width: bw - 3,
      height: bh - 3,
    ),
    Paint()..color = _darker(tier, 0.35),
  );
  c.drawOval(
    Rect.fromCenter(
      center: baseC - Offset(0, bh * 0.04),
      width: bw - 3,
      height: bh - 6,
    ),
    Paint()..color = tier,
  );
  c.drawOval(
    Rect.fromCenter(
      center: baseC - Offset(bw * 0.12, bh * 0.14),
      width: bw * 0.4,
      height: bh * 0.22,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
  // The figurine, with a little idle bounce.
  final ph = t * 2.6 + (d.id.hashCode % 7);
  final squash = 1 + math.sin(ph) * 0.035;
  final h = rr * 2.05 * squash;
  final dst = _fit(img, baseC, h, rr * 2.3 / squash);
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (disabled) {
    paint.colorFilter = const ColorFilter.matrix(<double>[
      0.25, 0.4, 0.1, 0, 10, //
      0.25, 0.4, 0.1, 0, 10,
      0.25, 0.4, 0.1, 0, 22,
      0, 0, 0, 0.8, 0,
    ]);
  }
  c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    paint,
  );
}

/// A riftling or boss: waddles, flashes white when hit, goes icy when slowed.
void _drawCritter(
  Canvas c,
  Offset p,
  double r,
  ui.Image img,
  double t, {
  double flash = 0,
  bool frozen = false,
  double waddle = 1,
  double alpha = 1,
}) {
  final ph = t * 9 + p.dx * 0.05;
  final hop = math.sin(ph).abs() * r * 0.12 * waddle;
  final tilt = math.sin(ph) * 0.09 * waddle;
  final feet = p + Offset(0, r * 0.9);
  c.drawOval(
    Rect.fromCenter(center: feet, width: r * 1.5, height: r * 0.42),
    Paint()..color = Colors.black.withValues(alpha: 0.3 * alpha),
  );
  c.save();
  c.translate(feet.dx, feet.dy - hop);
  c.rotate(tilt);
  final dst = _fit(img, Offset.zero, r * 2.1, r * 2.4);
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (flash > 0) {
    paint.colorFilter = ColorFilter.mode(
      Colors.white.withValues(alpha: 0.75 * alpha),
      BlendMode.srcATop,
    );
  } else if (frozen) {
    paint.colorFilter = ColorFilter.mode(
      const Color(0xFF8FE3FF).withValues(alpha: 0.55 * alpha),
      BlendMode.srcATop,
    );
  } else if (alpha < 1) {
    paint.color = Colors.white.withValues(alpha: alpha);
  }
  if (flash > 0 || frozen) {
    if (alpha < 1) paint.color = Colors.white.withValues(alpha: alpha);
  }
  c.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    paint,
  );
  c.restore();
}

/// Paint a figurine onto a widget (album, info cards).
class UnitIcon extends StatelessWidget {
  final UnitDef def;
  final double size;
  final bool locked;
  const UnitIcon(this.def, {super.key, this.size = 48, this.locked = false});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: locked
        ? CustomPaint(painter: _UnitIconPainter(def, locked))
        : Image.asset(
            'assets/sprites/u_${def.id}.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                CustomPaint(painter: _UnitIconPainter(def, locked)),
          ),
  );
}

class _UnitIconPainter extends CustomPainter {
  final UnitDef def;
  final bool locked;
  _UnitIconPainter(this.def, this.locked);
  @override
  void paint(Canvas canvas, Size size) {
    if (locked) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width * 0.42,
        Paint()..color = const Color(0xFF2A2440),
      );
      drawText(
        canvas,
        '?',
        size.center(Offset.zero),
        size.width * 0.4,
        Colors.white38,
      );
      return;
    }
    drawUnit(
      canvas,
      size.center(Offset.zero) - Offset(0, size.height * 0.04),
      size.width * 0.4,
      def,
      0,
    );
  }

  @override
  bool shouldRepaint(covariant _UnitIconPainter old) =>
      old.def != def || old.locked != locked;
}

class EnemyIcon extends StatelessWidget {
  final EnemyDef? enemy;
  final BossDef? boss;
  final double size;
  const EnemyIcon({super.key, this.enemy, this.boss, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final name = boss != null
        ? 'b_${boss!.id}'
        : 'e_${enemy!.id == 'wibble' ? 'wobbler' : enemy!.id}';
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/sprites/$name.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            CustomPaint(painter: _EnemyIconPainter(enemy, boss)),
      ),
    );
  }
}

class _EnemyIconPainter extends CustomPainter {
  final EnemyDef? e;
  final BossDef? b;
  _EnemyIconPainter(this.e, this.b);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (b != null) {
      drawBoss(
        canvas,
        c + Offset(0, size.height * 0.1),
        size.width * 0.3,
        b!,
        0,
      );
    } else {
      drawEnemy(canvas, c, size.width * 0.28, e!, 0);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

ui.Picture? cachedPicture;
