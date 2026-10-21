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
  VisFx(
    this.type,
    this.x,
    this.y, {
    this.x2 = 0,
    this.y2 = 0,
    this.vx = 0,
    this.vy = 0,
    required this.color,
    this.text = '',
    this.size = 1,
    required this.life,
  });
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
    origin = Offset(
      (size.width - field.w * scale) / 2,
      (size.height - field.h * scale) / 2,
    );
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
      if (cx >= 0 && cx < kBoardCols && cy >= 0 && cy < kBoardRows) {
        return (s, cy * kBoardCols + cx);
      }
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
  FieldPainter(
    this.g,
    this.fx,
    this.t, {
    this.selected,
    this.dragFrom,
    this.dragPos,
    this.shake = Offset.zero,
    this.freezeFlash = 0,
    this.tutorialHighlight = -1,
  });

  static ui.Picture? _bg;
  static Size? _bgSize;
  static GameMode? _bgMode;
  static int? _bgLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = FieldGeom(g.field, size);
    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    if (_bg == null ||
        _bgSize != size ||
        _bgMode != g.cfg.mode ||
        _bgLevel != g.cfg.level) {
      final rec = ui.PictureRecorder();
      _paintStatic(Canvas(rec), size, geo);
      _bg = rec.endRecording();
      _bgSize = size;
      _bgMode = g.cfg.mode;
      _bgLevel = g.cfg.level;
    }
    canvas.drawPicture(_bg!);
    _paintWaves(canvas, size, geo);
    // Festoon bulbs retired in the rustic pass: the backdrop carries the
    // fairground lights, and blinking dots on the deck read as clutter.
    _paintBoards(canvas, geo);
    _paintEnemies(canvas, geo);
    _paintFx(canvas, geo);
    _paintDrag(canvas, geo);
    canvas.restore();
    if (freezeFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFF7FDBFF)
              .withValues(alpha: 0.25 * freezeFlash),
      );
    }
    final lc = g.laneCount;
    if (lc > kLaneLimit * 0.7) {
      final a =
          ((lc - kLaneLimit * 0.7) / (kLaneLimit * 0.3)).clamp(0.0, 1.0) *
          (0.5 + 0.5 * math.sin(t * 8));
      final r = Offset.zero & size;
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              Pal.danger.withValues(alpha: 0.45 * a),
            ],
            stops: const [0.6, 1.0],
          ).createShader(r),
      );
    }
  }

  _Theme get _th => _Theme.of(g.cfg.level);

  void _paintStatic(Canvas c, Size size, FieldGeom geo) {
    final s = geo.scale;
    final th = _th;
    final f = g.field;
    // No painted sea: the fairground backdrop behind the screen shows
    // through, darkened, so the deck reads as a raised wooden stage.
    final deckRect = Rect.fromPoints(geo.px(0, 0), geo.px(f.w, f.h));
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0x59000000));
    // Soft contact shadow under the stage for depth.
    c.drawRRect(
      RRect.fromRectAndRadius(
        deckRect.inflate(s * 0.3).shift(Offset(s * 0.12, s * 0.22)),
        Radius.circular(s * 0.5),
      ),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
    );
    // Deck: outline, frame, then planks
    final frame = RRect.fromRectAndRadius(
      deckRect.inflate(s * 0.08),
      Radius.circular(s * 0.22),
    );
    c.drawRRect(
      frame.shift(Offset(0, s * 0.1)),
      Paint()..color = const Color(0x55000000),
    );
    c.drawRRect(frame.inflate(2), Paint()..color = Pal.ink);
    c.drawRRect(frame, Paint()..color = th.deckEdge);
    final deck = RRect.fromRectAndRadius(
      deckRect.deflate(s * 0.04),
      Radius.circular(s * 0.16),
    );
    c.drawRRect(deck, Paint()..color = th.deck);
    c.save();
    c.clipRRect(deck);
    final plankLine = Paint()
      ..color = th.deckLine
      ..strokeWidth = math.max(1, s * 0.025);
    final rnd = math.Random(3);
    for (var y = 0.0; y < f.h; y += 0.42) {
      final py = geo.px(0, y).dy;
      c.drawLine(
        Offset(deckRect.left, py),
        Offset(deckRect.right, py),
        plankLine,
      );
      for (
        var x = rnd.nextDouble() * 1.6;
        x < f.w;
        x += 1.4 + rnd.nextDouble()
      ) {
        final px = geo.px(x, 0).dx;
        c.drawLine(Offset(px, py), Offset(px, py + s * 0.42), plankLine);
      }
      // Weathering: darker grain streaks and a nail at each plank end.
      final grain = Paint()
        ..color = th.deckLine.withValues(alpha: 0.35)
        ..strokeWidth = math.max(1, s * 0.015);
      for (var k = 0; k < 3; k++) {
        final gx = deckRect.left + rnd.nextDouble() * deckRect.width;
        final gy = py + s * (0.1 + rnd.nextDouble() * 0.24);
        c.drawLine(
          Offset(gx, gy),
          Offset(gx + s * (0.5 + rnd.nextDouble()), gy + s * 0.02),
          grain,
        );
      }
      final nail = Paint()..color = const Color(0x664A3A2C);
      for (var x = 0.2; x < f.w; x += 1.4) {
        c.drawCircle(geo.px(x, y + 0.21), math.max(1, s * 0.03), nail);
      }
      c.drawRect(
        Rect.fromLTWH(deckRect.left, py + 1, deckRect.width, s * 0.06),
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
    }
    c.restore();
    // Lane: dark edge, boardwalk, seams, rope rails
    final path = Path();
    for (var i = 0; i <= f.pts.length; i++) {
      final p = geo.pv(f.pts[i % f.pts.length]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    Paint stroke(Color col, double w) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      path.shift(Offset(0, s * 0.06)),
      stroke(const Color(0x44000000), s * 0.92),
    );
    c.drawPath(path, stroke(Pal.ink, s * 0.9));
    c.drawPath(path, stroke(th.laneEdge, s * 0.84));
    c.drawPath(path, stroke(th.lane, s * 0.7));
    final seam = Paint()
      ..color = th.laneEdge.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, s * 0.03);
    for (var d = 0.0; d < f.lap; d += 0.3) {
      final a = f.posAt(d), b = f.posAt(d + 0.05);
      final dx = b.x - a.x, dy = b.y - a.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len * 0.34, ny = dx / len * 0.34;
      c.drawLine(geo.px(a.x + nx, a.y + ny), geo.px(a.x - nx, a.y - ny), seam);
    }
    // Slipway the sea things climb up
    final st = geo.pv(f.pts.first);
    c.drawCircle(st, s * 0.46, Paint()..color = Pal.ink);
    c.drawCircle(st, s * 0.42, Paint()..color = th.seaBottom);
    c.drawCircle(st, s * 0.3, Paint()..color = th.seaTop);
    // Boards: raised platform with tiles
    for (var side = 0; side < g.sides.length; side++) {
      final o = f.boardOrigin(side);
      final r = Rect.fromPoints(
        geo.px(o.x, o.y),
        geo.px(o.x + kBoardCols, o.y + kBoardRows),
      );
      final plat = RRect.fromRectAndRadius(
        r.inflate(s * 0.1),
        Radius.circular(s * 0.2),
      );
      c.drawRRect(
        plat.shift(Offset(0, s * 0.08)),
        Paint()..color = const Color(0x55000000),
      );
      c.drawRRect(plat.inflate(1.5), Paint()..color = Pal.ink);
      c.drawRRect(
        plat,
        Paint()..color = side == 0 ? th.platform : th.platform2,
      );
      for (var i = 0; i < kBoardCols * kBoardRows; i++) {
        final cc = geo.pv(f.cellCenter(side, i));
        final cr = Rect.fromCenter(center: cc, width: s * 0.9, height: s * 0.9);
        final alt = ((i % kBoardCols) + (i ~/ kBoardCols)) % 2 == 0;
        final base = side == 0 ? th.tile : th.tile2;
        final tile = alt ? base : Color.lerp(base, Colors.black, 0.06)!;
        c.drawRRect(
          RRect.fromRectAndRadius(
            cr.shift(Offset(0, s * 0.04)),
            Radius.circular(s * 0.14),
          ),
          Paint()..color = Color.lerp(tile, Colors.black, 0.28)!,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(cr, Radius.circular(s * 0.14)),
          Paint()..color = tile,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cr.left + s * 0.08,
              cr.top + s * 0.05,
              cr.width - s * 0.16,
              s * 0.14,
            ),
            Radius.circular(s * 0.07),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.22),
        );
      }
      if (g.cfg.mode == GameMode.coop) {
        final label = side == 0 ? 'YOU' : kPartnerName.toUpperCase();
        final lp = tp(label, s * 0.22, Colors.white);
        lp.paint(
          c,
          Offset(
            r.right - lp.width - s * 0.06,
            side == 0 ? r.bottom + s * 0.12 : r.top - lp.height - s * 0.12,
          ),
        );
      }
    }
    // Lamp posts along the long edges
    for (final y in [0.0, f.h]) {
      for (var x = 0.0; x <= f.w + 0.01; x += f.w / 6) {
        final p = geo.px(x, y);
        c.drawCircle(p, s * 0.13, Paint()..color = Pal.ink);
        c.drawCircle(p, s * 0.1, Paint()..color = th.post);
      }
    }
  }

  void _paintWaves(Canvas c, Size size, FieldGeom geo) {
    final th = _th;
    // No foam arcs: there is no painted sea any more, only fog on fog levels.
    if (th.fog > 0) {
      for (var i = 0; i < 4; i++) {
        final x =
            ((t * 10 + i * size.width / 4) % (size.width * 1.4)) -
            size.width * 0.2;
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x, size.height * (0.2 + i * 0.2)),
            width: size.width * 0.6,
            height: size.height * 0.18,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: th.fog)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
        );
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
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: cc, width: s * 0.98, height: s * 0.98),
              Radius.circular(s * 0.16),
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Pal.neon.withValues(alpha: 0.5 + 0.5 * math.sin(t * 6)),
          );
        }
        if (cell.isEmpty) continue;
        final d = cell.def!;
        if (dragFrom == i && p.index == 0) continue;
        final canMerge = g.canMerge(p, i);
        if (canMerge) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: cc, width: s * 0.92, height: s * 0.92),
              Radius.circular(s * 0.14),
            ),
            Paint()
              ..color = Color(Tier.values[d.tier.index + 1].color)
                  .withValues(alpha: 0.18 + 0.14 * math.sin(t * 5)),
          );
        }
        if (isSel) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: cc, width: s * 0.96, height: s * 0.96),
              Radius.circular(s * 0.16),
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = Pal.neon,
          );
          // range ring
          final range =
              d.range +
              (p.activeUnions().contains('Sea') && d.tags.contains('Sea')
                  ? 0.6
                  : 0);
          c.drawCircle(
            cc,
            range * s,
            Paint()..color = Colors.white.withValues(alpha: 0.06),
          );
          c.drawCircle(
            cc,
            range * s,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white.withValues(alpha: 0.35),
          );
        }
        final n = cell.units.length;
        final disabled = cell.disabled > 0;
        final offs = n == 1
            ? [Offset.zero]
            : n == 2
            ? [Offset(-s * 0.17, s * 0.04), Offset(s * 0.17, -s * 0.04)]
            : [
                Offset(-s * 0.2, s * 0.12),
                Offset(s * 0.2, s * 0.12),
                Offset(0, -s * 0.16),
              ];
        final r =
            s *
            (n == 1
                ? 0.36
                : n == 2
                ? 0.27
                : 0.23);
        for (var k = n - 1; k >= 0; k--) {
          final u = cell.units[k];
          final age = g.time - u.born;
          final pop = age < 0.35
              ? 1 + math.sin(age / 0.35 * math.pi) * 0.45
              : 1.0;
          drawUnit(
            c,
            cc + offs[k],
            r,
            d,
            t + k * 0.7,
            disabled: disabled,
            pop: pop,
            showMono: n == 1,
          );
        }
        if (n > 1) {
          final bp = cc + Offset(s * 0.3, -s * 0.32);
          c.drawCircle(bp, s * 0.14, Paint()..color = Pal.ink);
          c.drawCircle(
            bp,
            s * 0.115,
            Paint()
              ..color = canMerge
                  ? const Color(0xFF3DB43A)
                  : const Color(0xFF2E7CE3),
          );
          drawText(c, '$n', bp, s * 0.17, Colors.white);
        }
        if (disabled) _tape(c, cc, s);
      }
    }
  }

  void _tape(Canvas c, Offset cc, double s) {
    c.save();
    c.translate(cc.dx, cc.dy);
    c.rotate(-0.5);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: s * 1.1,
      height: s * 0.22,
    );
    c.drawRect(r, Paint()..color = Pal.neon);
    for (var x = -s * 0.55; x < s * 0.55; x += s * 0.18) {
      c.drawRect(
        Rect.fromLTWH(x, -s * 0.11, s * 0.08, s * 0.22),
        Paint()..color = Pal.ink,
      );
    }
    c.restore();
    drawText(
      c,
      'CONDEMNED',
      cc + Offset(0, s * 0.36),
      s * 0.13,
      Pal.neon,
      shadow: true,
    );
  }

  void _paintEnemies(Canvas c, FieldGeom geo) {
    final s = geo.scale;
    // bosses last, so they sit on top
    final sorted = [...g.enemies]
      ..sort((a, b) => (a.isBoss ? 1 : 0).compareTo(b.isBoss ? 1 : 0));
    for (final e in sorted) {
      if (e.dead) continue;
      final p = geo.pv(g.field.posAt(e.s));
      final frozen = e.freezeT > 0;
      if (e.isBoss) {
        drawBoss(
          c,
          p,
          s * 0.42,
          e.boss!,
          t,
          flash: e.hitFlash,
          submerged: e.submerged,
          shield: e.shield,
        );
      } else {
        drawEnemy(
          c,
          p,
          s * e.def!.size,
          e.def!,
          t + e.id * 0.37,
          flash: e.hitFlash,
          frozen: frozen,
        );
      }
      final r = e.isBoss ? s * 0.42 : s * e.def!.size;
      if (e.curseT > 0) {
        c.drawCircle(
          p,
          r * 1.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xCC6FD3C8),
        );
      }
      if (e.burnT > 0) {
        final fl = Paint()
          ..color = const Color(0xFFFFA62B).withValues(alpha: 0.8);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
            p +
                Offset(
                  (i - 1) * r * 0.5,
                  -r * (0.9 + 0.3 * math.sin(t * 12 + i)),
                ),
            r * 0.16,
            fl,
          );
        }
      }
      if (e.stunT > 0) {
        for (var i = 0; i < 3; i++) {
          final a = t * 5 + i * 2.1;
          c.drawCircle(
            p + Offset(math.cos(a) * r * 0.8, -r * 1.1 + math.sin(a) * r * 0.2),
            r * 0.12,
            Paint()..color = Pal.neon,
          );
        }
      }
      if (e.slowT > 0 && e.slowPct > 0) {
        c.drawOval(
          Rect.fromCenter(
            center: p + Offset(0, r * 0.8),
            width: r * 1.8,
            height: r * 0.5,
          ),
          Paint()..color = const Color(0x88FFB3E1),
        );
      }
      if (!e.isBoss && e.hp < e.maxHp) {
        final w = r * 2;
        final bar = Rect.fromLTWH(
          p.dx - w / 2,
          p.dy - r - s * 0.12,
          w,
          math.max(2, s * 0.05),
        );
        c.drawRect(bar, Paint()..color = Colors.black54);
        c.drawRect(
          Rect.fromLTWH(
            bar.left,
            bar.top,
            w * (e.hp / e.maxHp).clamp(0, 1),
            bar.height,
          ),
          Paint()..color = e.def!.id == 'pollock' ? Pal.neon : Pal.danger,
        );
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
            f.type == FxType.beam
                ? p
                : Offset.lerp(p, q, math.max(0, k * 3 - 0.6))!,
            head,
            Paint()
              ..color = f.color.withValues(alpha: a)
              ..strokeWidth = (f.type == FxType.beam ? 3.2 : 1.8) * f.size
              ..strokeCap = StrokeCap.round,
          );
          if (k > 0.3) {
            c.drawCircle(
              q,
              s * 0.08 * (1 - k) * f.size,
              Paint()..color = Colors.white.withValues(alpha: a),
            );
          }
        case FxType.hit:
          drawText(
            c,
            f.text,
            p + Offset(0, -k * s * 0.6),
            s * 0.26 * f.size,
            f.color.withValues(alpha: 1 - k * k),
            shadow: true,
          );
        case FxType.text:
          drawText(
            c,
            f.text,
            p + Offset(0, -k * s * 0.8),
            s * 0.24 * f.size,
            f.color.withValues(alpha: 1 - k * k),
            shadow: true,
          );
        case FxType.miss:
          drawText(
            c,
            'miss',
            p + Offset(0, -k * s * 0.5),
            s * 0.18,
            Colors.white.withValues(alpha: 0.7 * (1 - k)),
          );
        case FxType.kill:
          // particle
          c.drawCircle(
            p,
            s * 0.07 * f.size * (1 - k),
            Paint()..color = f.color.withValues(alpha: 1 - k),
          );
        case FxType.summon:
        case FxType.merge:
        case FxType.mythic:
          final rr = s * (0.3 + k * (0.6 + f.size * 0.25));
          c.drawCircle(
            p,
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth =
                  s * 0.08 * (1 - k) * (f.type == FxType.summon ? 1 : 2)
              ..color = f.color.withValues(alpha: 1 - k),
          );
          if (f.type != FxType.summon) {
            for (var i = 0; i < 8; i++) {
              final a = i * math.pi / 4 + k;
              c.drawCircle(
                p + Offset(math.cos(a), math.sin(a)) * rr * 1.1,
                s * 0.05 * (1 - k),
                Paint()..color = f.color,
              );
            }
          }
        case FxType.pulse:
          c.drawCircle(
            p,
            f.size * s * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.12 * (1 - k)
              ..color = f.color.withValues(alpha: 0.7 * (1 - k)),
          );
        case FxType.jackpot:
          drawText(
            c,
            'JACKPOT!',
            p + Offset(0, -s * 0.6 - k * s * 0.5),
            s * (0.3 + 0.1 * math.sin(k * 20)),
            Pal.neon.withValues(alpha: 1 - k),
            shadow: true,
          );
        case FxType.sell:
          drawText(
            c,
            '+',
            p + Offset(0, -k * s * 0.5),
            s * 0.4,
            f.color.withValues(alpha: 1 - k),
          );
        case FxType.condemn:
          c.drawCircle(
            p,
            s * (0.5 + k),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Pal.neon.withValues(alpha: 1 - k),
          );
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
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: cc,
            width: geo.scale * 0.95,
            height: geo.scale * 0.95,
          ),
          Radius.circular(geo.scale * 0.16),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Pal.neon,
      );
    }
    drawUnit(
      c,
      dragPos! - Offset(0, geo.scale * 0.3),
      geo.scale * 0.36,
      cell.def!,
      t,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Colours for each level's pier.
class _Theme {
  final Color seaTop,
      seaBottom,
      shallow,
      foam,
      deck,
      deckEdge,
      deckLine,
      lane,
      laneEdge,
      platform,
      platform2,
      tile,
      tile2,
      legs,
      post;
  final List<Color> bulbs;
  final double fog;
  const _Theme({
    required this.seaTop,
    required this.seaBottom,
    required this.shallow,
    required this.foam,
    required this.deck,
    required this.deckEdge,
    required this.deckLine,
    required this.lane,
    required this.laneEdge,
    required this.platform,
    required this.platform2,
    required this.tile,
    required this.tile2,
    required this.legs,
    required this.post,
    required this.bulbs,
    this.fog = 0,
  });

  static const _all = [
    // Grimley Pier: warm boards on a bright sea
    _Theme(
      seaTop: Color(0xFF2FB7DD),
      seaBottom: Color(0xFF1479B8),
      shallow: Color(0x8870E6E9),
      foam: Colors.white,
      deck: Color(0xFFC98A52),
      deckEdge: Color(0xFF7E4A26),
      deckLine: Color(0xFF9C6236),
      lane: Color(0xFFF2D49B),
      laneEdge: Color(0xFFB98B55),
      platform: Color(0xFF6E4A2E),
      platform2: Color(0xFF4F5D73),
      tile: Color(0xFFF6E6BF),
      tile2: Color(0xFFDCE7F2),
      legs: Color(0xFF5B3A22),
      post: Color(0xFF2E7CE3),
      bulbs: [
        Color(0xFFFFE07A),
        Color(0xFFFF8FB1),
        Color(0xFF8FE3FF),
        Color(0xFFFFB45A),
      ],
    ),
    // Fogbank Arcade: grey-green sea, painted arcade boards
    _Theme(
      seaTop: Color(0xFF5FA9A8),
      seaBottom: Color(0xFF2D6475),
      shallow: Color(0x88A8E0D6),
      foam: Colors.white,
      deck: Color(0xFF9A6FA8),
      deckEdge: Color(0xFF55356A),
      deckLine: Color(0xFF7A5089),
      lane: Color(0xFFF4D7E8),
      laneEdge: Color(0xFFB98BAA),
      platform: Color(0xFF4B2F5E),
      platform2: Color(0xFF3F566E),
      tile: Color(0xFFFBE7F2),
      tile2: Color(0xFFDDE9F0),
      legs: Color(0xFF3E2650),
      post: Color(0xFFE5539A),
      bulbs: [Color(0xFFFF8FD8), Color(0xFF8FFFE0), Color(0xFFFFE07A)],
      fog: 0.08,
    ),
    // Crab Cove: turquoise shallows and sandy boards
    _Theme(
      seaTop: Color(0xFF3FE0D8),
      seaBottom: Color(0xFF169CB8),
      shallow: Color(0xAAF6E2A8),
      foam: Colors.white,
      deck: Color(0xFFE0B072),
      deckEdge: Color(0xFF9A6534),
      deckLine: Color(0xFFBD8A4E),
      lane: Color(0xFFFFF0C8),
      laneEdge: Color(0xFFD1A867),
      platform: Color(0xFF8A5A30),
      platform2: Color(0xFF55708A),
      tile: Color(0xFFFFF4D8),
      tile2: Color(0xFFE2F0F6),
      legs: Color(0xFF6B4423),
      post: Color(0xFFE2443C),
      bulbs: [Color(0xFFFFE07A), Color(0xFFFF7A6B), Color(0xFFFFFFFF)],
    ),
    // The Void Pier: purple-black water, cold lights
    _Theme(
      seaTop: Color(0xFF3A1F73),
      seaBottom: Color(0xFF120A33),
      shallow: Color(0x667E5CFF),
      foam: Color(0xFFC9B8FF),
      deck: Color(0xFF4A3D6B),
      deckEdge: Color(0xFF241B3D),
      deckLine: Color(0xFF382D57),
      lane: Color(0xFFB9A8E6),
      laneEdge: Color(0xFF6E5BA8),
      platform: Color(0xFF241B3D),
      platform2: Color(0xFF1E2C47),
      tile: Color(0xFFDCD2F7),
      tile2: Color(0xFFCFE0F2),
      legs: Color(0xFF1A1330),
      post: Color(0xFF8B52E3),
      bulbs: [Color(0xFF8FE3FF), Color(0xFFC9A0FF), Color(0xFFFFFFFF)],
      fog: 0.05,
    ),
  ];

  static final _weatheredAll = [for (final t in _all) t._weathered()];
  static _Theme of(int level) =>
      _weatheredAll[(level - 1) % _weatheredAll.length];

  /// Rustic pass: every level keeps its own hue but reads as sun-bleached,
  /// salt-stained paint over old timber rather than fresh candy colours.
  _Theme _weathered() {
    Color w(Color c, [double k = 0.38]) {
      final m = Color.lerp(c, const Color(0xFF5E4B39), k)!;
      return Color.lerp(
        m,
        const Color(0xFF000000),
        0.12,
      )!.withValues(alpha: c.a);
    }

    return _Theme(
      seaTop: w(seaTop),
      seaBottom: w(seaBottom),
      shallow: w(shallow),
      foam: w(foam, 0.2),
      deck: w(deck, 0.3),
      deckEdge: w(deckEdge, 0.3),
      deckLine: w(deckLine, 0.3),
      lane: w(lane, 0.3),
      laneEdge: w(laneEdge, 0.3),
      platform: w(platform),
      platform2: w(platform2),
      tile: w(tile, 0.28),
      tile2: w(tile2, 0.28),
      legs: w(legs),
      post: w(post),
      bulbs: [for (final b in bulbs) w(b, 0.25)],
      fog: fog,
    );
  }
}
