// The pier: lane, boards, figurines, riftlings and all the juice.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/sim.dart';
import 'art.dart';
import 'widgets.dart' show Vx;

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
    _paintBondLinks(canvas, geo);
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
          ((lc - kLaneLimit * 0.7) / (kLaneLimit * 0.3)).clamp(0.0, 1.0) * 0.8;
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
    final th = _th;
    final f = g.field;
    final s = geo.scale;
    // ---- the plaza: one raised stone slab with a chunky front edge --------
    final slab = Rect.fromPoints(geo.px(0, 0), geo.px(f.w, f.h));
    final rr = RRect.fromRectAndRadius(slab, Radius.circular(s * 0.42));
    c.drawRRect(
      rr.shift(Offset(0, s * 0.3)),
      Paint()
        ..color = const Color(0x9008061A)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.22),
    );
    c.drawRRect(rr.shift(Offset(0, s * 0.17)), Paint()..color = th.edge);
    c.drawRRect(rr, Paint()..color = th.grout);
    c.save();
    c.clipRRect(rr);
    // flagstones in staggered rows, each a slightly different tint, lit
    // from the top left
    final rnd = math.Random(11 + g.cfg.level);
    final gap = math.max(1.2, s * 0.045);
    var y = 0.0;
    var row = 0;
    while (y < f.h) {
      final rh = 0.72 + rnd.nextDouble() * 0.3;
      var x = row.isOdd ? -0.55 : 0.0;
      while (x < f.w) {
        final rw = 0.9 + rnd.nextDouble() * 0.7;
        final r = Rect.fromPoints(
          geo.px(x, y),
          geo.px(x + rw, y + rh),
        ).deflate(gap / 2);
        final k = rnd.nextDouble();
        final col = k < 0.5
            ? Color.lerp(th.stone, th.stoneLight, k * 1.4)!
            : Color.lerp(th.stone, th.stoneDark, (k - 0.5) * 1.1)!;
        final sr = RRect.fromRectAndRadius(r, Radius.circular(s * 0.07));
        c.drawRRect(sr, Paint()..color = col);
        c.drawRRect(
          sr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, s * 0.025)
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.38),
                Colors.white.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.14),
              ],
              stops: const [0, 0.5, 1],
            ).createShader(r),
        );
        x += rw;
      }
      y += rh;
      row++;
    }
    // soft light across the whole slab, brighter at the top
    c.drawRect(
      slab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.black.withValues(alpha: 0.10),
          ],
        ).createShader(slab),
    );
    // ---- the riftlings' track: a worn groove round each board -------------
    for (final w in f.walks) {
      final path = Path();
      for (var i = 0; i < w.length; i++) {
        final q = geo.pv(w[i]);
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      final cap = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      c.drawPath(
        path,
        Paint.from(cap)
          ..strokeWidth = s * 0.8
          ..color = th.grooveEdge,
      );
      c.drawPath(
        path.shift(Offset(0, s * 0.05)),
        Paint.from(cap)
          ..strokeWidth = s * 0.66
          ..color = th.groove,
      );
      // worn cobble seams across the groove
      final pm = path.computeMetrics();
      for (final m in pm) {
        for (var d = s * 0.5; d < m.length; d += s * 0.5) {
          final tan = m.getTangentForOffset(d);
          if (tan == null) continue;
          final n = Offset(-tan.vector.dy, tan.vector.dx) * (s * 0.26);
          final at = tan.position + Offset(0, s * 0.05);
          c.drawLine(
            at - n,
            at + n,
            Paint()
              ..strokeWidth = math.max(1, s * 0.022)
              ..color = th.grooveEdge.withValues(alpha: 0.5),
          );
        }
      }
    }
    // ---- the Rift: a jagged violet crack through the middle ---------------
    final hatch = geo.pv(f.hatch);
    final coop = f.mode == GameMode.coop;
    final x0 = coop ? 1.05 : f.hatch.x - 2.4;
    final x1 = coop ? f.w - 1.05 : f.hatch.x + 2.4;
    final crack = Path();
    final cr = math.Random(5);
    var first = true;
    for (var x = x0; x <= x1 + 0.001; x += 0.32) {
      final edge = math.min(x - x0, x1 - x) / (x1 - x0) * 2;
      final jit = (cr.nextDouble() - 0.5) * 0.16 * (0.4 + edge);
      final q = geo.px(x, f.hatch.y + jit);
      first ? crack.moveTo(q.dx, q.dy) : crack.lineTo(q.dx, q.dy);
      first = false;
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      crack,
      Paint.from(line)
        ..strokeWidth = s * 0.34
        ..color = Vx.rift.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.12),
    );
    c.drawPath(
      crack,
      Paint.from(line)
        ..strokeWidth = s * 0.13
        ..color = const Color(0xFF1C0F45),
    );
    c.drawPath(
      crack,
      Paint.from(line)
        ..strokeWidth = math.max(1.2, s * 0.04)
        ..color = const Color(0xFFD9CCFF),
    );
    // the tear the riftlings climb out of
    final tear = Path();
    final tr = math.Random(9);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2;
      final rad = s * (0.36 + tr.nextDouble() * 0.12);
      final q =
          hatch + Offset(math.cos(a) * rad * 1.15, math.sin(a) * rad * 0.8);
      i == 0 ? tear.moveTo(q.dx, q.dy) : tear.lineTo(q.dx, q.dy);
    }
    tear.close();
    c.drawPath(
      tear,
      Paint()
        ..color = Vx.rift.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
    );
    c.drawPath(
      tear,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFFF3EDFF),
            Color(0xFFA78BFF),
            Color(0xFF4A27A8),
            Color(0xFF1C0F45),
          ],
          stops: const [0, 0.3, 0.75, 1],
        ).createShader(Rect.fromCircle(center: hatch, radius: s * 0.5)),
    );
    c.drawPath(
      tear,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.03)
        ..color = const Color(0xFF1C0F45),
    );
    c.restore();
    // a light rim along the top of the slab
    c.drawRRect(
      rr.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.25],
        ).createShader(slab),
    );
    // ---- the two boards: a raised dais each, with deep sockets -----------
    for (var side = 0; side < (f.mode == GameMode.coop ? 2 : 1); side++) {
      final o = f.boardOrigin(side);
      final br = Rect.fromPoints(
        geo.pv(o),
        geo.px(o.x + kBoardCols, o.y + kBoardRows),
      ).inflate(s * 0.12);
      final drr = RRect.fromRectAndRadius(br, Radius.circular(s * 0.26));
      final mine = side == 0;
      c.drawRRect(drr.shift(Offset(0, s * 0.1)), Paint()..color = th.daisEdge);
      c.drawRRect(
        drr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [th.dais, Color.lerp(th.dais, th.daisEdge, 0.3)!],
          ).createShader(br),
      );
      c.drawRRect(
        drr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, s * 0.06)
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: mine
                ? const [Color(0xFFFFE48A), Color(0xFFC98A2B)]
                : const [Color(0xFFD5DCEC), Color(0xFF7480A0)],
          ).createShader(br),
      );
      for (var i = 0; i < kBoardCols * kBoardRows; i++) {
        final cc = geo.pv(f.cellCenter(side, i));
        final cr2 = Rect.fromCenter(
          center: cc,
          width: s * 0.84,
          height: s * 0.84,
        );
        final rr2 = RRect.fromRectAndRadius(cr2, Radius.circular(s * 0.2));
        // rim
        c.drawRRect(rr2.inflate(s * 0.02), Paint()..color = th.socketRim);
        // recess: dark at the top left where the lip shades it
        c.drawRRect(rr2, Paint()..color = th.socketDeep);
        final face = rr2.deflate(s * 0.02).shift(Offset(s * 0.025, s * 0.045));
        c.save();
        c.clipRRect(rr2);
        c.drawRRect(
          face,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0.1, 0.25),
              radius: 0.8,
              colors: [th.socket, Color.lerp(th.socket, th.socketDeep, 0.3)!],
            ).createShader(cr2),
        );
        c.restore();
        // catch-light on the bottom-right of the rim
        c.drawRRect(
          rr2.inflate(s * 0.01),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, s * 0.025)
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.45),
              ],
              stops: const [0, 0.5, 1],
            ).createShader(cr2),
        );
      }
      // name tab on the board's outer edge
      final label = mine
          ? 'YOU'
          : (g.cfg.mode == GameMode.solo ? '' : 'BRENDA');
      if (label.isNotEmpty) {
        final ty = mine ? br.bottom : br.top;
        final tpaint = tp(label, s * 0.2, Colors.white);
        final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(br.center.dx, ty),
            width: tpaint.width + s * 0.4,
            height: s * 0.32,
          ),
          Radius.circular(s * 0.16),
        );
        c.drawRRect(
          pill.shift(Offset(0, s * 0.04)),
          Paint()
            ..color = mine ? const Color(0xFF8A5A14) : const Color(0xFF3E4766),
        );
        c.drawRRect(
          pill,
          Paint()
            ..color = mine ? const Color(0xFFE2A93A) : const Color(0xFF7C88AA),
        );
        tpaint.paint(
          c,
          Offset(br.center.dx - tpaint.width / 2, ty - tpaint.height / 2),
        );
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

  /// A short brass link across the edge between each pair of touching cells
  /// with a bond on. It sits on the cell borders, so it never covers the
  /// figurines.
  void _paintBondLinks(Canvas c, FieldGeom geo) {
    final s = geo.scale;
    for (final p in g.sides) {
      for (final b in p.bonds) {
        final a = geo.pv(g.field.cellCenter(p.index, b.i));
        final z = geo.pv(g.field.cellCenter(p.index, b.j));
        final mid = Offset((a.dx + z.dx) / 2, (a.dy + z.dy) / 2);
        final dir = z - a;
        final len = dir.distance;
        if (len <= 0) continue;
        final u = dir / len;
        final half = s * 0.22;
        final glow = Paint()
          ..color = const Color(0xFF6B4410)
          ..strokeWidth = math.max(4.0, s * (b.k > 1 ? 0.16 : 0.12))
          ..strokeCap = StrokeCap.round;
        final line = Paint()
          ..color = const Color(0xFFF2C25A)
          ..strokeWidth = math.max(2.0, s * (b.k > 1 ? 0.1 : 0.07))
          ..strokeCap = StrokeCap.round;
        c.drawLine(mid - u * half, mid + u * half, glow);
        c.drawLine(mid - u * half, mid + u * half, line);
        c.drawCircle(
          mid,
          math.max(2.5, s * 0.07),
          Paint()..color = const Color(0xFFFFE6A6),
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
              ..color = Vx.gold,
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
                  .withValues(alpha: 0.3),
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
              ..strokeWidth = 3
              ..color = Colors.white,
          );
          // The range ring only shows while dragging (see _paintDrag).
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
      final p = geo.pv(g.field.at(e));
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
          ..strokeWidth = 2.5
          ..color = Colors.white,
      );
      // faint chalk range ring, only while dragging
      final d = cell.def!;
      final range =
          d.range +
          (g.you.activeUnions().contains('Sea') && d.tags.contains('Sea')
              ? 0.6
              : 0);
      c.drawCircle(
        cc,
        range * geo.scale,
        Paint()..color = Colors.white.withValues(alpha: 0.07),
      );
      c.drawCircle(
        cc,
        range * geo.scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.4),
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
  final Color stone, stoneLight, stoneDark, grout, edge;
  final Color groove, grooveEdge;
  final Color dais, daisEdge, socket, socketDeep, socketRim;
  final double fog;
  const _Theme({
    required this.stone,
    required this.stoneLight,
    required this.stoneDark,
    required this.grout,
    required this.edge,
    required this.groove,
    required this.grooveEdge,
    required this.dais,
    required this.daisEdge,
    required this.socket,
    required this.socketDeep,
    required this.socketRim,
    this.fog = 0,
  });

  // One stone per level: pale lavender slate, warm sandstone, sea-green
  // slate in fog, rose granite, cool blue slate, then dark rift glass.
  static const _all = [
    _Theme(
      stone: Color(0xFFCFC8DE),
      stoneLight: Color(0xFFE6E1F0),
      stoneDark: Color(0xFFB4ABC8),
      grout: Color(0xFF8E85A6),
      edge: Color(0xFF5E5578),
      groove: Color(0xFFA79DBE),
      grooveEdge: Color(0xFF7D7398),
      dais: Color(0xFF9E95B8),
      daisEdge: Color(0xFF5B5276),
      socket: Color(0xFFBBB4CF),
      socketDeep: Color(0xFF6C6386),
      socketRim: Color(0xFFBDB5D2),
    ),
    _Theme(
      stone: Color(0xFFE3CFAE),
      stoneLight: Color(0xFFF2E3C8),
      stoneDark: Color(0xFFCDB48D),
      grout: Color(0xFFA48A66),
      edge: Color(0xFF6E5638),
      groove: Color(0xFFC2A882),
      grooveEdge: Color(0xFF977C58),
      dais: Color(0xFFB79C78),
      daisEdge: Color(0xFF6A5236),
      socket: Color(0xFFD1BB98),
      socketDeep: Color(0xFF7D6446),
      socketRim: Color(0xFFD9C3A0),
    ),
    _Theme(
      stone: Color(0xFFBFD3CC),
      stoneLight: Color(0xFFD8E6E1),
      stoneDark: Color(0xFFA2BAB2),
      grout: Color(0xFF7C958D),
      edge: Color(0xFF486058),
      groove: Color(0xFF9BB3AB),
      grooveEdge: Color(0xFF6F8981),
      dais: Color(0xFF8FA79F),
      daisEdge: Color(0xFF465D56),
      socket: Color(0xFFACC1BA),
      socketDeep: Color(0xFF587068),
      socketRim: Color(0xFFB2C8C1),
      fog: 0.05,
    ),
    _Theme(
      stone: Color(0xFFE3C4C2),
      stoneLight: Color(0xFFF1DCDA),
      stoneDark: Color(0xFFCCA6A4),
      grout: Color(0xFFA4807E),
      edge: Color(0xFF6E4B4B),
      groove: Color(0xFFC4A19F),
      grooveEdge: Color(0xFF99777A),
      dais: Color(0xFFB5918F),
      daisEdge: Color(0xFF6A4848),
      socket: Color(0xFFD1B0AE),
      socketDeep: Color(0xFF7D5A5A),
      socketRim: Color(0xFFD8B9B7),
    ),
    _Theme(
      stone: Color(0xFFC0CCE0),
      stoneLight: Color(0xFFD8E1EE),
      stoneDark: Color(0xFFA4B3CC),
      grout: Color(0xFF7F8EAA),
      edge: Color(0xFF4A5674),
      groove: Color(0xFF9CAAC4),
      grooveEdge: Color(0xFF71809E),
      dais: Color(0xFF8F9DBA),
      daisEdge: Color(0xFF475373),
      socket: Color(0xFFACB9D1),
      socketDeep: Color(0xFF596685),
      socketRim: Color(0xFFB2BED6),
    ),
    _Theme(
      stone: Color(0xFF7D7399),
      stoneLight: Color(0xFF948BB0),
      stoneDark: Color(0xFF675D84),
      grout: Color(0xFF4A4166),
      edge: Color(0xFF2B2445),
      groove: Color(0xFF5E5480),
      grooveEdge: Color(0xFF433A63),
      dais: Color(0xFF5A5079),
      daisEdge: Color(0xFF2A2342),
      socket: Color(0xFF6F658C),
      socketDeep: Color(0xFF362E50),
      socketRim: Color(0xFF8C82AA),
      fog: 0.04,
    ),
  ];

  static _Theme of(int level) => _all[(level - 1) % _all.length];
}
