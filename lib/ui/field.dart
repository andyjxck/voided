// The pier: lane, boards, figurines, sea things and all the juice.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/sim.dart';
import 'art.dart';

class VisFx {
  final FxType type;
  double x, y;
  final double x2, y2;
  double vx, vy;
  final Color color;
  final String text;
  final double size;
  double age = 0;
  final double life;
  VisFx(this.type, this.x, this.y,
      {this.x2 = 0, this.y2 = 0, this.vx = 0, this.vy = 0, required this.color, this.text = '', this.size = 1, required this.life});
  double get k => (age / life).clamp(0.0, 1.0);
}

/// Maps field units to pixels.
class FieldGeom {
  final Field field;
  final Size size;
  late final double scale;
  late final Offset origin;
  FieldGeom(this.field, this.size) {
    scale = math.min(size.width / field.w, size.height / field.h);
    origin = Offset((size.width - field.w * scale) / 2, (size.height - field.h * scale) / 2);
  }
  Offset px(double x, double y) => origin + Offset(x * scale, y * scale);
  Offset pv(V2 v) => px(v.x, v.y);

  /// (side, cell) under a pixel, or null.
  (int, int)? cellAt(Offset p, int sides) {
    final fx = (p.dx - origin.dx) / scale;
    final fy = (p.dy - origin.dy) / scale;
    for (var s = 0; s < sides; s++) {
      final o = field.boardOrigin(s);
      final cx = (fx - o.x).floor();
      final cy = (fy - o.y).floor();
      if (cx >= 0 && cx < kBoardCols && cy >= 0 && cy < kBoardRows) return (s, cy * kBoardCols + cx);
    }
    return null;
  }
}

class FieldPainter extends CustomPainter {
  final Game g;
  final List<VisFx> fx;
  final double t;
  final int? selected;
  final int? dragFrom;
  final Offset? dragPos;
  final Offset shake;
  final double freezeFlash;
  final int tutorialHighlight;
  FieldPainter(this.g, this.fx, this.t,
      {this.selected, this.dragFrom, this.dragPos, this.shake = Offset.zero, this.freezeFlash = 0, this.tutorialHighlight = -1});

  static ui.Picture? _bg;
  static Size? _bgSize;
  static GameMode? _bgMode;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = FieldGeom(g.field, size);
    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    if (_bg == null || _bgSize != size || _bgMode != g.cfg.mode) {
      final rec = ui.PictureRecorder();
      _paintStatic(Canvas(rec), size, geo);
      _bg = rec.endRecording();
      _bgSize = size;
      _bgMode = g.cfg.mode;
    }
    canvas.drawPicture(_bg!);
    _paintWaves(canvas, size, geo);
    _paintLights(canvas, geo);
    _paintBoards(canvas, geo);
    _paintEnemies(canvas, geo);
    _paintFx(canvas, geo);
    _paintDrag(canvas, geo);
    canvas.restore();
    if (freezeFlash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF7FDBFF).withValues(alpha: 0.25 * freezeFlash));
    }
    final lc = g.laneCount;
    if (lc > kLaneLimit * 0.7) {
      final a = ((lc - kLaneLimit * 0.7) / (kLaneLimit * 0.3)).clamp(0.0, 1.0) * (0.5 + 0.5 * math.sin(t * 8));
      final r = Offset.zero & size;
      canvas.drawRect(
          r,
          Paint()
            ..shader = RadialGradient(colors: [Colors.transparent, Pal.danger.withValues(alpha: 0.45 * a)], stops: const [0.6, 1.0])
                .createShader(r));
    }
  }

  void _paintStatic(Canvas c, Size size, FieldGeom geo) {
    final s = geo.scale;
    c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF070E22), Pal.sea2])
              .createShader(Offset.zero & size));
    // Pier legs peeking out under the deck
    final legs = Paint()..color = const Color(0xFF2A1C14);
    final f = g.field;
    final deckRect = Rect.fromPoints(geo.px(0, 0), geo.px(f.w, f.h));
    for (var x = 0.4; x < f.w; x += 1.2) {
      c.drawRect(Rect.fromLTWH(geo.px(x, 0).dx, deckRect.bottom - 2, s * 0.18, s * 0.45), legs);
    }
    // Deck under everything
    c.drawRRect(RRect.fromRectAndRadius(deckRect.inflate(s * 0.04), Radius.circular(s * 0.25)), Paint()..color = Pal.deckDark);
    // Lane planks
    final lane = Paint()
      ..color = Pal.plank
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.9
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.square;
    final path = Path();
    for (var i = 0; i <= f.pts.length; i++) {
      final p = geo.pv(f.pts[i % f.pts.length]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, lane);
    final seam = Paint()
      ..color = const Color(0xFF5E4130)
      ..strokeWidth = math.max(1, s * 0.03);
    for (var d = 0.0; d < f.lap; d += 0.34) {
      final a = f.posAt(d), b = f.posAt(d + 0.05);
      final dx = b.x - a.x, dy = b.y - a.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len * 0.42, ny = dx / len * 0.42;
      c.drawLine(geo.px(a.x + nx, a.y + ny), geo.px(a.x - nx, a.y - ny), seam);
    }
    // Start marker: the slipway the sea things climb up
    final st = geo.pv(f.pts.first);
    c.drawCircle(st, s * 0.42, Paint()..color = const Color(0xFF0E3B4A));
    c.drawCircle(st, s * 0.3, Paint()..color = const Color(0xFF1B6A80));
    // Boards
    for (var side = 0; side < g.sides.length; side++) {
      final o = f.boardOrigin(side);
      final r = Rect.fromPoints(geo.px(o.x, o.y), geo.px(o.x + kBoardCols, o.y + kBoardRows));
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(s * 0.06), Radius.circular(s * 0.18)),
          Paint()..color = side == 0 ? const Color(0xFF3A2A4D) : const Color(0xFF2B2F45));
      for (var i = 0; i < kBoardCols * kBoardRows; i++) {
        final cc = geo.pv(f.cellCenter(side, i));
        final cr = Rect.fromCenter(center: cc, width: s * 0.9, height: s * 0.9);
        c.drawRRect(RRect.fromRectAndRadius(cr, Radius.circular(s * 0.14)),
            Paint()..color = side == 0 ? const Color(0xFF4A3763) : const Color(0xFF383D58));
        c.drawRRect(
            RRect.fromRectAndRadius(cr.deflate(s * 0.08), Radius.circular(s * 0.1)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: 0.05));
      }
      if (g.cfg.mode == GameMode.coop) {
        final label = side == 0 ? 'YOU' : kPartnerName.toUpperCase();
        final lp = tp(label, s * 0.22, Colors.white.withValues(alpha: 0.35));
        lp.paint(c, Offset(r.right - lp.width - s * 0.08, side == 0 ? r.bottom + s * 0.02 : r.top - lp.height - s * 0.02));
      }
    }
  }

  void _paintWaves(Canvas c, Size size, FieldGeom geo) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.05);
    final rect = Rect.fromPoints(geo.px(0, 0), geo.px(g.field.w, g.field.h));
    for (var y = 12.0; y < size.height; y += 26) {
      if (y > rect.top - 4 && y < rect.bottom + 4 && rect.left < 30) continue;
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 12) {
        final yy = y + math.sin(x / 40 + t * 1.2 + y) * 3;
        x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      c.drawPath(path, p);
    }
  }

  void _paintLights(Canvas c, FieldGeom geo) {
    // Strings of bulbs round the outside of the pier.
    final f = g.field;
    final r = geo.scale * 0.06;
    var i = 0;
    for (var x = 0.15; x < f.w; x += 0.55) {
      for (final y in [0.06, f.h - 0.06]) {
        final on = ((i + (t * 3).floor()) % 3) != 0;
        final col = [Pal.neon, Pal.danger, const Color(0xFF7FDBFF)][i % 3];
        c.drawCircle(geo.px(x, y), r * (on ? 1.3 : 1.0), Paint()..color = on ? col : col.withValues(alpha: 0.25));
        i++;
      }
    }
  }

  void _paintBoards(Canvas c, FieldGeom geo) {
    final s = geo.scale;
    for (final p in g.sides) {
      for (var i = 0; i < p.cells.length; i++) {
        final cell = p.cells[i];
        final cc = geo.pv(g.field.cellCenter(p.index, i));
        final isSel = p.index == 0 && selected == i;
        if (p.index == 0 && tutorialHighlight == i) {
          c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: cc, width: s * 0.98, height: s * 0.98), Radius.circular(s * 0.16)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Pal.neon.withValues(alpha: 0.5 + 0.5 * math.sin(t * 6)));
        }
        if (cell.isEmpty) continue;
        final d = cell.def!;
        if (dragFrom == i && p.index == 0) continue;
        final canMerge = g.canMerge(p, i);
        if (canMerge) {
          c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: cc, width: s * 0.92, height: s * 0.92), Radius.circular(s * 0.14)),
              Paint()..color = Color(Tier.values[d.tier.index + 1].color).withValues(alpha: 0.18 + 0.14 * math.sin(t * 5)));
        }
        if (isSel) {
          c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: cc, width: s * 0.96, height: s * 0.96), Radius.circular(s * 0.16)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = Colors.white);
          // range ring
          final range = d.range + (p.activeUnions().contains('Sea') && d.tags.contains('Sea') ? 0.6 : 0);
          c.drawCircle(cc, range * s, Paint()..color = Colors.white.withValues(alpha: 0.06));
          c.drawCircle(
              cc,
              range * s,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = Colors.white.withValues(alpha: 0.35));
        }
        final n = cell.units.length;
        final disabled = cell.disabled > 0;
        final offs = n == 1
            ? [Offset.zero]
            : n == 2
                ? [Offset(-s * 0.17, s * 0.04), Offset(s * 0.17, -s * 0.04)]
                : [Offset(-s * 0.2, s * 0.12), Offset(s * 0.2, s * 0.12), Offset(0, -s * 0.16)];
        final r = s * (n == 1 ? 0.36 : n == 2 ? 0.27 : 0.23);
        for (var k = n - 1; k >= 0; k--) {
          final u = cell.units[k];
          final age = g.time - u.born;
          final pop = age < 0.35 ? 1 + math.sin(age / 0.35 * math.pi) * 0.45 : 1.0;
          drawUnit(c, cc + offs[k], r, d, t + k * 0.7, disabled: disabled, pop: pop, showMono: n == 1);
        }
        if (n > 1) {
          final bp = cc + Offset(s * 0.3, -s * 0.32);
          c.drawCircle(bp, s * 0.12, Paint()..color = Pal.ink);
          drawText(c, '$n', bp, s * 0.16, canMerge ? Pal.neon : Colors.white);
        }
        if (disabled) _tape(c, cc, s);
      }
    }
  }

  void _tape(Canvas c, Offset cc, double s) {
    c.save();
    c.translate(cc.dx, cc.dy);
    c.rotate(-0.5);
    final r = Rect.fromCenter(center: Offset.zero, width: s * 1.1, height: s * 0.22);
    c.drawRect(r, Paint()..color = Pal.neon);
    for (var x = -s * 0.55; x < s * 0.55; x += s * 0.18) {
      c.drawRect(Rect.fromLTWH(x, -s * 0.11, s * 0.08, s * 0.22), Paint()..color = Pal.ink);
    }
    c.restore();
    drawText(c, 'CONDEMNED', cc + Offset(0, s * 0.36), s * 0.13, Pal.neon, shadow: true);
  }

  void _paintEnemies(Canvas c, FieldGeom geo) {
    final s = geo.scale;
    // bosses last, so they sit on top
    final sorted = [...g.enemies]..sort((a, b) => (a.isBoss ? 1 : 0).compareTo(b.isBoss ? 1 : 0));
    for (final e in sorted) {
      if (e.dead) continue;
      final p = geo.pv(g.field.posAt(e.s));
      final frozen = e.freezeT > 0;
      if (e.isBoss) {
        drawBoss(c, p, s * 0.42, e.boss!, t, flash: e.hitFlash, submerged: e.submerged, shield: e.shield);
      } else {
        drawEnemy(c, p, s * e.def!.size, e.def!, t + e.id * 0.37, flash: e.hitFlash, frozen: frozen);
      }
      final r = e.isBoss ? s * 0.42 : s * e.def!.size;
      if (e.curseT > 0) {
        c.drawCircle(
            p,
            r * 1.3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = const Color(0xCC6FD3C8));
      }
      if (e.burnT > 0) {
        final fl = Paint()..color = const Color(0xFFFFA62B).withValues(alpha: 0.8);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(p + Offset((i - 1) * r * 0.5, -r * (0.9 + 0.3 * math.sin(t * 12 + i))), r * 0.16, fl);
        }
      }
      if (e.stunT > 0) {
        for (var i = 0; i < 3; i++) {
          final a = t * 5 + i * 2.1;
          c.drawCircle(p + Offset(math.cos(a) * r * 0.8, -r * 1.1 + math.sin(a) * r * 0.2), r * 0.12, Paint()..color = Pal.neon);
        }
      }
      if (e.slowT > 0 && e.slowPct > 0) {
        c.drawOval(Rect.fromCenter(center: p + Offset(0, r * 0.8), width: r * 1.8, height: r * 0.5),
            Paint()..color = const Color(0x88FFB3E1));
      }
      if (!e.isBoss && e.hp < e.maxHp) {
        final w = r * 2;
        final bar = Rect.fromLTWH(p.dx - w / 2, p.dy - r - s * 0.12, w, math.max(2, s * 0.05));
        c.drawRect(bar, Paint()..color = Colors.black54);
        c.drawRect(Rect.fromLTWH(bar.left, bar.top, w * (e.hp / e.maxHp).clamp(0, 1), bar.height),
            Paint()..color = e.def!.id == 'pollock' ? Pal.neon : Pal.danger);
      }
    }
  }

  void _paintFx(Canvas c, FieldGeom geo) {
    final s = geo.scale;
    for (final f in fx) {
      final k = f.k;
      final p = geo.px(f.x, f.y);
      switch (f.type) {
        case FxType.shot:
        case FxType.beam:
          final q = geo.px(f.x2, f.y2);
          final a = (1 - k);
          final head = Offset.lerp(p, q, math.min(1, k * 3))!;
          c.drawLine(
              f.type == FxType.beam ? p : Offset.lerp(p, q, math.max(0, k * 3 - 0.6))!,
              head,
              Paint()
                ..color = f.color.withValues(alpha: a)
                ..strokeWidth = (f.type == FxType.beam ? 3.2 : 1.8) * f.size
                ..strokeCap = StrokeCap.round);
          if (k > 0.3) c.drawCircle(q, s * 0.08 * (1 - k) * f.size, Paint()..color = Colors.white.withValues(alpha: a));
        case FxType.hit:
          drawText(c, f.text, p + Offset(0, -k * s * 0.6), s * 0.26 * f.size, f.color.withValues(alpha: 1 - k * k), shadow: true);
        case FxType.text:
          drawText(c, f.text, p + Offset(0, -k * s * 0.8), s * 0.24 * f.size, f.color.withValues(alpha: 1 - k * k), shadow: true);
        case FxType.miss:
          drawText(c, 'miss', p + Offset(0, -k * s * 0.5), s * 0.18, Colors.white.withValues(alpha: 0.7 * (1 - k)));
        case FxType.kill:
          // particle
          c.drawCircle(p, s * 0.07 * f.size * (1 - k), Paint()..color = f.color.withValues(alpha: 1 - k));
        case FxType.summon:
        case FxType.merge:
        case FxType.mythic:
          final rr = s * (0.3 + k * (0.6 + f.size * 0.25));
          c.drawCircle(
              p,
              rr,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = s * 0.08 * (1 - k) * (f.type == FxType.summon ? 1 : 2)
                ..color = f.color.withValues(alpha: 1 - k));
          if (f.type != FxType.summon) {
            for (var i = 0; i < 8; i++) {
              final a = i * math.pi / 4 + k;
              c.drawCircle(p + Offset(math.cos(a), math.sin(a)) * rr * 1.1, s * 0.05 * (1 - k), Paint()..color = f.color);
            }
          }
        case FxType.pulse:
          c.drawCircle(
              p,
              f.size * s * k,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = s * 0.12 * (1 - k)
                ..color = f.color.withValues(alpha: 0.7 * (1 - k)));
        case FxType.jackpot:
          drawText(c, 'JACKPOT!', p + Offset(0, -s * 0.6 - k * s * 0.5), s * (0.3 + 0.1 * math.sin(k * 20)), Pal.neon.withValues(alpha: 1 - k), shadow: true);
        case FxType.sell:
          drawText(c, '+', p + Offset(0, -k * s * 0.5), s * 0.4, f.color.withValues(alpha: 1 - k));
        case FxType.condemn:
          c.drawCircle(p, s * (0.5 + k), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Pal.neon.withValues(alpha: 1 - k));
        default:
          break;
      }
    }
  }

  void _paintDrag(Canvas c, FieldGeom geo) {
    if (dragFrom == null || dragPos == null) return;
    final cell = g.you.cells[dragFrom!];
    if (cell.isEmpty) return;
    final target = geo.cellAt(dragPos!, 1);
    if (target != null) {
      final cc = geo.pv(g.field.cellCenter(0, target.$2));
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: cc, width: geo.scale * 0.95, height: geo.scale * 0.95), Radius.circular(geo.scale * 0.16)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Pal.neon);
    }
    drawUnit(c, dragPos! - Offset(0, geo.scale * 0.3), geo.scale * 0.36, cell.def!, t);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
