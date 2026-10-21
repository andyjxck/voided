// The run: HUD, the pier, the machine, and every button you will mash.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../game/ai.dart';
import '../game/data.dart';
import '../game/meta.dart';
import '../game/sim.dart';
import 'a11y.dart';
import 'art.dart';
import 'field.dart';
import 'widgets.dart';

class TutStep {
  final String title;
  final String body;
  final String wait; // next | summon | merge
  const TutStep(this.title, this.body, this.wait);
}

const List<TutStep> kTutorial = [
  TutStep('Welcome to Grimley Pier',
      'Last night of the season, and things are climbing out of the sea. They walk the boardwalk round and round. If $kLaneLimit are on the pier at once, it\'s over.',
      'next'),
  TutStep('Feed the machine', 'Tap SUMMON. Every penny in the Oracle-O-Matic gives you a random figurine, and they fight for you. Summon three.', 'summon'),
  TutStep('Three of a kind', 'Same figurines stack, three to a cell. Tap a full stack and press MERGE to squash them into one random figurine from the next tier up. Merging is how you get strong.', 'next'),
  TutStep('Move them about', 'Drag a figurine onto another cell to swap them. Cells next to the boardwalk see the most action, so put your best ones there.', 'next'),
  TutStep('Luck and grease', 'Tea leaves come every fifth wave and from bosses. Spend them on a gamble for rare figurines. ELBOW GREASE makes a whole tier hit harder. MYTHICS shows the recipes for the four legends of the pier.', 'next'),
  TutStep('Bosses', 'Every 10th wave a boss turns up, and you have $kBossSeconds seconds to get rid of it. Wave $kFinalWave is the Landlord. Good luck, love.', 'next'),
];

class GameScreen extends StatefulWidget {
  final MetaSave meta;
  final GameMode mode;
  final Difficulty difficulty;
  final bool tutorial;
  final VoidCallback onSave;
  const GameScreen({super.key, required this.meta, required this.mode, required this.difficulty, required this.onSave, this.tutorial = false});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Game g;
  Bot? brenda;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double t = 0;
  int speed = 1;
  bool paused = false;
  int? selected;
  int? dragFrom;
  Offset? dragPos;
  final List<VisFx> vfx = [];
  double shakeAmt = 0;
  Offset shake = Offset.zero;
  double freezeFlash = 0;
  String? toast;
  double toastT = 0;
  String? banner;
  String? bannerSub;
  double bannerT = 0;
  int tut = -1;
  int _tutSummons = 0;
  bool _ended = false;
  RunSummary? summary;
  final ValueNotifier<int> frame = ValueNotifier(0);
  // One node for the whole screen. (A new FocusNode per build leaked 60 nodes
  // a second and stole focus every frame, which broke taps in the browser.)
  final FocusNode _keysFocus = FocusNode(debugLabel: 'game keys');
  final math.Random _r = math.Random();
  FieldGeom? _geo;
  int _lastChat = 0;
  bool _wasBoss = false;
  GameNarrator _narr = GameNarrator();
  static const _swapHere = CustomSemanticsAction(label: 'Swap with the selected spot');

  /// True while a screen reader (or the browser's accessibility tree) is on.
  bool get _a11y => SemanticsBinding.instance.semanticsEnabled;

  @override
  void initState() {
    super.initState();
    _newGame();
    if (widget.tutorial) tut = 0;
    _ticker = createTicker(_onTick)..start();
  }

  void _newGame() {
    g = Game(widget.meta.configFor(widget.mode, widget.difficulty, DateTime.now().millisecondsSinceEpoch & 0x7fffffff));
    brenda = g.partner == null ? null : Bot(g, g.partner!, thinkEvery: 0.9, skill: 0.9, chatty: true);
    if (g.partner != null) g.say(kPartnerName, 'Right, love. You take the bottom, I\'ll take the top. Mind the crabs.');
    _ended = false;
    summary = null;
    selected = null;
    vfx.clear();
    _narr = GameNarrator();
    _lastChat = g.chat.length;
    Sfx.musicMood(false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    frame.dispose();
    _keysFocus.dispose();
    super.dispose();
  }

  bool get _tutBlocking => tut >= 0 && tut < kTutorial.length && kTutorial[tut].wait == 'next';

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0.1) dt = 0.1;
    t += dt;
    final running = !paused && !_tutBlocking && g.status == GameStatus.playing;
    if (running) {
      final sdt = dt * speed;
      brenda?.update(sdt);
      g.update(sdt);
    }
    _consumeFx();
    for (final f in vfx) {
      f.age += dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
    }
    vfx.removeWhere((f) => f.age >= f.life);
    shakeAmt = math.max(0, shakeAmt - dt * 30);
    final sh = widget.meta.shake ? shakeAmt : 0.0;
    shake = sh > 0 ? Offset((_r.nextDouble() - 0.5) * sh, (_r.nextDouble() - 0.5) * sh) : Offset.zero;
    freezeFlash = math.max(0, freezeFlash - dt * 1.5);
    if (toastT > 0) toastT -= dt;
    if (bannerT > 0) bannerT -= dt;
    final isBoss = g.boss != null;
    if (isBoss != _wasBoss) {
      _wasBoss = isBoss;
      Sfx.musicMood(isBoss);
    }
    if (g.status != GameStatus.playing && !_ended) _end();
    // Spoken updates: at most one line every two seconds, and only with a
    // screen reader on. The narrator tracks state either way, so turning one
    // on mid-run doesn't replay old events.
    final said = _narr.update(g, dt);
    if (_a11y && mounted) {
      for (final s in said) {
        SemanticsService.sendAnnouncement(View.of(context), s.text, TextDirection.ltr,
            assertiveness: s.urgent ? Assertiveness.assertive : Assertiveness.polite);
      }
    }
    frame.value++;
    setState(() {});
  }

  bool _mine(Fx f) => g.cfg.mode == GameMode.solo || f.y > g.field.boardOrigin(0).y - 0.2;

  void _consumeFx() {
    for (final f in g.fx) {
      switch (f.type) {
        case FxType.shot:
        case FxType.beam:
          if (vfx.length < 380) {
            vfx.add(VisFx(f.type, f.x, f.y, x2: f.x2, y2: f.y2, color: Color(f.color), size: f.size, life: f.type == FxType.beam ? 0.22 : 0.16));
          }
          Sfx.hit(t);
        case FxType.hit:
          vfx.add(VisFx(f.type, f.x, f.y, color: Color(f.color), text: f.text, size: f.size, life: 0.7));
        case FxType.kill:
          final n = f.size >= 3 ? 24 : 6;
          for (var i = 0; i < n && vfx.length < 450; i++) {
            final a = _r.nextDouble() * math.pi * 2;
            final sp = (0.6 + _r.nextDouble() * 1.4) * (f.size >= 3 ? 2 : 1);
            vfx.add(VisFx(FxType.kill, f.x, f.y, vx: math.cos(a) * sp, vy: math.sin(a) * sp, color: Color(f.color), size: f.size >= 3 ? 2 : 1, life: 0.45 + _r.nextDouble() * 0.3));
          }
          Sfx.kill(t, f.size >= 3);
          if (f.size >= 3) shakeAmt += 14;
        case FxType.summon:
        case FxType.merge:
        case FxType.mythic:
          vfx.add(VisFx(f.type, f.x, f.y, color: Color(f.color), size: f.size, life: f.type == FxType.mythic ? 1.2 : 0.6));
          if (_mine(f)) {
            if (f.type == FxType.summon) Sfx.summon(f.size.round());
            if (f.type == FxType.merge) Sfx.merge(f.size.round());
            if (f.type == FxType.mythic) Sfx.mythic();
            if (f.size >= 3 && f.type != FxType.mythic) {
              final d = kUnitById[f.text];
              if (d != null) _showBanner(d.tier.label.toUpperCase(), d.name);
            }
            if (f.type == FxType.mythic) {
              final d = kUnitById[f.text];
              if (d != null) {
                _showBanner('MYTHIC', d.name);
                _narr.note('Mythic built: ${d.name}.');
              }
            }
          }
        case FxType.boss:
          _showBanner('WAVE ${g.wave}: ${f.text.toUpperCase()}', bossForWave(g.wave).mechText, secs: 3.5);
          Sfx.boss();
        case FxType.shake:
          shakeAmt += f.size * 10;
        case FxType.text:
          vfx.add(VisFx(f.type, f.x, f.y, color: Color(f.color), text: f.text, size: f.size, life: 1.0));
        case FxType.miss:
          if (vfx.length < 380) vfx.add(VisFx(f.type, f.x, f.y, color: Colors.white, life: 0.5));
        case FxType.pulse:
          vfx.add(VisFx(f.type, f.x, f.y, color: Color(f.color), size: f.size, life: 0.4));
        case FxType.jackpot:
          vfx.add(VisFx(f.type, f.x, f.y, color: Color(f.color), life: 1.2));
          Sfx.jackpot();
        case FxType.freeze:
          freezeFlash = 1;
          Sfx.freeze();
        case FxType.condemn:
          vfx.add(VisFx(f.type, f.x, f.y, color: Pal.neon, life: 0.8));
          Sfx.condemn();
        case FxType.gamble:
          break;
        case FxType.sell:
          vfx.add(VisFx(f.type, f.x, f.y, color: Color(f.color), life: 0.6));
      }
    }
    g.fx.clear();
  }

  void _showBanner(String a, String b, {double secs = 2.2}) {
    banner = a;
    bannerSub = b;
    bannerT = secs;
  }

  void _toast(String s) {
    if (s.isEmpty) return;
    toast = s;
    toastT = 2.2;
    _narr.note(s);
    Sfx.error();
  }

  void _end() {
    _ended = true;
    summary = widget.meta.finishRun(g);
    widget.onSave();
    if (g.status == GameStatus.won) {
      Sfx.win();
    } else {
      Sfx.lose();
    }
  }

  // ---------------- actions ----------------
  void _summon() {
    Sfx.unlock();
    final r = g.summon(g.you);
    if (!r.ok) return _toast(r.msg);
    _narr.note('Summoned ${r.unit!.name}, ${r.unit!.tier.label}.', kind: 'summon');
    if (tut == 1) {
      _tutSummons++;
      if (_tutSummons >= 3) tut++;
    }
  }

  void _tapField(Offset p) {
    final geo = _geo;
    if (geo == null) return;
    final hit = geo.cellAt(p, g.sides.length);
    if (hit == null || hit.$1 != 0) {
      setState(() => selected = null);
      return;
    }
    Sfx.click();
    setState(() => selected = (selected == hit.$2 || g.you.cells[hit.$2].isEmpty) ? null : hit.$2);
  }

  void _panStart(Offset p) {
    final hit = _geo?.cellAt(p, 1);
    if (hit == null || hit.$1 != 0 || g.you.cells[hit.$2].isEmpty) return;
    dragFrom = hit.$2;
    dragPos = p;
  }

  void _panEnd() {
    if (dragFrom != null && dragPos != null) {
      final hit = _geo?.cellAt(dragPos!, 1);
      if (hit != null && hit.$1 == 0 && hit.$2 != dragFrom) {
        g.swap(g.you, dragFrom!, hit.$2);
        Sfx.click();
        _narr.note('Moved to ${spotName(hit.$2)}.');
        if (selected == dragFrom) selected = hit.$2;
      }
    }
    dragFrom = null;
    dragPos = null;
  }

  void _merge(int i) {
    final r = g.merge(g.you, i);
    if (!r.ok) return _toast(r.msg);
    _narr.note('Merged into ${r.unit!.name}, ${r.unit!.tier.label}.');
    if (tut == 2) tut++;
    setState(() => selected = null);
  }

  /// A double-tap on one of the screen reader's spot buttons: same as a tap.
  void _tapCell(int i) {
    Sfx.click();
    setState(() => selected = (selected == i || g.you.cells[i].isEmpty) ? null : i);
    if (selected == i) _narr.note('Selected. ${cellLabel(g, i)} Merge, sell, shake and give are below the board.');
  }

  bool get _tutCanNext =>
      tut >= 0 && tut < kTutorial.length && (kTutorial[tut].wait == 'next' || (kTutorial[tut].wait == 'summon' && _tutSummons >= 3));

  void _tutNext() => setState(() {
        Sfx.unlock();
        tut++;
        if (tut >= kTutorial.length) {
          tut = -1;
          widget.meta.tutorialDone = true;
          widget.onSave();
        }
      });

  void _keys(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    final k = e.logicalKey;
    if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) && _tutCanNext) return _tutNext();
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyS) _summon();
    if (k == LogicalKeyboardKey.keyP || k == LogicalKeyboardKey.escape) setState(() => paused = !paused);
    if (k == LogicalKeyboardKey.keyM && selected != null && g.canMerge(g.you, selected!)) _merge(selected!);
    if (k == LogicalKeyboardKey.keyF) setState(() => speed = speed == 1 ? 2 : 1);
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.sea,
      body: KeyboardListener(
        focusNode: _keysFocus,
        autofocus: true,
        onKeyEvent: _keys,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 860 && c.maxWidth > c.maxHeight * 1.05;
            return Stack(children: [
              if (wide)
                Row(children: [
                  Expanded(child: Column(children: [_hud(true), if (g.boss != null) _bossBar(), Expanded(child: _fieldArea())])),
                  SizedBox(width: 360, child: _sidePanel()),
                ])
              else
                Column(children: [
                  _hud(false),
                  if (g.boss != null) _bossBar(),
                  Expanded(child: _fieldArea()),
                  _selectionPanel(),
                  _controls(false),
                ]),
              if (tut >= 0 && tut < kTutorial.length) _tutorialCard(wide),
              if (paused && !_ended) _pauseOverlay(),
              if (_ended) _endOverlay(),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _hud(bool wide) {
    final p = g.you;
    final lc = g.laneCount;
    final timer = g.boss != null ? g.bossTimer : g.waveTimer;
    final waveLabel = g.wave == 0 ? 'GET READY' : 'WAVE ${g.wave}${g.endless ? '' : '/$kFinalWave'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      color: Pal.panel,
      child: Row(children: [
        Expanded(
          // One readable line for the whole bar, built from whole seconds and
          // counts, so it changes about once a second, not every frame.
          child: Semantics(
            container: true,
            label: hudLabel(g),
            excludeSemantics: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(waveLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                const SizedBox(width: 8),
                Text('${timer.ceil()}s',
                    style: TextStyle(color: g.boss != null && timer < 15 ? Pal.danger : Colors.white54, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 4),
            LaneMeter(count: lc, limit: kLaneLimit),
          ]),
          ),
        ),
        const SizedBox(width: 8),
        // Pennies and leaves are already in the bar's label.
        ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CurrencyChip(icon: Icons.circle, color: Pal.penny, value: '${p.pennies}'),
            const SizedBox(width: 4),
            CurrencyChip(icon: Icons.eco, color: Pal.leaf, value: '${p.leaves}'),
          ]),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: speed == 1 ? 'Speed up (F)' : 'Normal speed (F)',
          onPressed: () => setState(() => speed = speed == 1 ? 2 : 1),
          icon: Text('${speed}x', style: TextStyle(color: speed == 2 ? Pal.neon : Colors.white70, fontWeight: FontWeight.w900)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Pause (P)',
          onPressed: () => setState(() => paused = true),
          icon: const Icon(Icons.pause_rounded, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _bossBar() {
    final b = g.boss!;
    final frac = (b.hp / b.maxHp).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: bossLabel(g),
      excludeSemantics: true,
      child: Container(
      color: const Color(0xFF2A0F22),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Text('${b.name.toUpperCase()}  ·  ${b.boss!.title}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5))),
          Text('${g.bossTimer.ceil()}s', style: TextStyle(color: g.bossTimer < 15 ? Pal.danger : Colors.white70, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 9, color: Colors.black45),
            FractionallySizedBox(widthFactor: frac, child: Container(height: 9, color: Color(b.boss!.color).withValues(alpha: 1).withRed(230))),
            if (b.shield > 0)
              FractionallySizedBox(
                  widthFactor: (b.shield / b.maxHp).clamp(0.0, 1.0), child: Container(height: 9, color: const Color(0xCC9EE7FF))),
          ]),
        ),
      ]),
      ),
    );
  }

  Widget _fieldArea() {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      _geo = FieldGeom(g.field, size);
      final chat = g.chat.isNotEmpty && g.time - g.chat.last.at < 4.5 ? g.chat.last : null;
      if (g.chat.length != _lastChat) _lastChat = g.chat.length;
      final geo = _geo!;
      final boards = [
        boardSummary(g, g.you, owner: 'Your'),
        if (g.partner != null) boardSummary(g, g.partner!, owner: "$kPartnerName's"),
      ].join(' ');
      return Stack(children: [
        Semantics(
          container: true,
          label: 'The pier. $boards',
          excludeSemantics: true,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Pick up the figurine under the finger where it went down. The
          // default reports where the drag was recognised, after the touch
          // slop, which on a phone is often the next spot along.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => _tapField(d.localPosition),
          onPanStart: (d) => _panStart(d.localPosition),
          onPanUpdate: (d) => dragFrom != null ? dragPos = d.localPosition : null,
          onPanEnd: (_) => _panEnd(),
          onPanCancel: _panEnd,
          child: CustomPaint(
            size: size,
            painter: FieldPainter(g, vfx, t,
                selected: selected,
                dragFrom: dragFrom,
                dragPos: dragPos,
                shake: shake,
                freezeFlash: freezeFlash,
                tutorialHighlight: tut == 2 ? _firstMergeable() : -1),
          ),
        ),
        ),
        // With a screen reader on, every spot on your board is its own button:
        // double-tap selects it (Merge, Sell and the rest then appear), and a
        // custom action swaps it with the selected spot. They paint nothing,
        // let pointer events through, and are only built when needed.
        if (_a11y)
          for (var i = 0; i < g.you.cells.length; i++)
            Positioned.fromRect(
              rect: _cellRect(geo, i),
              child: Semantics(
                button: true,
                label: cellLabel(g, i, selected: selected == i),
                onTap: () => _tapCell(i),
                customSemanticsActions: selected != null && selected != i
                    ? {
                        _swapHere: () {
                          final from = selected!;
                          g.swap(g.you, from, i);
                          _narr.note('Swapped ${spotName(from)} and ${spotName(i)}.');
                          setState(() => selected = i);
                        },
                      }
                    : null,
                child: const SizedBox.expand(),
              ),
            ),
        if (chat != null)
          Positioned(
            left: 8,
            right: 8,
            top: 6,
            child: IgnorePointer(
                child: Semantics(
                    container: true,
                    label: '${chat.speaker} says: ${chat.text}',
                    excludeSemantics: true,
                    child: SpeechBubble(speaker: chat.speaker, text: chat.text))),
          ),
        // The banner and toast are spoken as announcements, so the tree skips
        // them rather than growing and shrinking a node under the reader.
        if (bannerT > 0 && banner != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(child: Center(child: BigBanner(title: banner!, sub: bannerSub ?? '', k: bannerT))),
            ),
          ),
        if (toastT > 0 && toast != null)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(child: ExcludeSemantics(child: Center(child: ToastPill(text: toast!)))),
          ),
      ]);
    });
  }

  Rect _cellRect(FieldGeom geo, int i) {
    final o = g.field.boardOrigin(0);
    final x = o.x + i % kBoardCols;
    final y = o.y + i ~/ kBoardCols;
    return Rect.fromPoints(geo.px(x, y), geo.px(x + 1, y + 1));
  }

  int _firstMergeable() {
    for (var i = 0; i < g.you.cells.length; i++) {
      if (g.canMerge(g.you, i)) return i;
    }
    return -1;
  }

  Widget _selectionPanel() {
    final i = selected;
    if (i == null || g.you.cells[i].isEmpty) return const SizedBox.shrink();
    final cell = g.you.cells[i];
    final d = cell.def!;
    final (rp, rl) = g.rerollCost(d.tier);
    final ingredientOf = [for (final e in kRecipes.entries) if (e.value.contains(d.id)) kUnitById[e.key]!.name];
    return Container(
      color: Pal.panel2,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UnitIcon(d, size: 44),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d.name}  ×${cell.units.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15), overflow: TextOverflow.ellipsis),
              Text('${d.tier.label} · ${d.tags.join(', ')} · ${(d.dps * g.dmgMult(g.you, d)).toStringAsFixed(0)} dps each',
                  style: TextStyle(color: Color(d.tier.color), fontSize: 12, fontWeight: FontWeight.w700)),
              Text(d.desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (ingredientOf.isNotEmpty)
                Text('Ingredient for ${ingredientOf.join(', ')}', style: const TextStyle(color: Color(0xFFFF5E7E), fontSize: 11)),
            ]),
          ),
          IconButton(onPressed: () => setState(() => selected = null), icon: const Icon(Icons.close, color: Colors.white54)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ActionBtn(
            label: 'MERGE',
            sub: d.tier.index < 3 ? '3 → 1 ${Tier.values[d.tier.index + 1].label}' : 'can\'t',
            color: Pal.neon,
            enabled: g.canMerge(g.you, i),
            onTap: () => _merge(i),
          ),
          ActionBtn(
            label: 'SELL',
            sub: d.tier == Tier.mythic ? 'never' : (sellLeaves(d.tier) > 0 ? '+${sellLeaves(d.tier)} leaf' : '+${sellPennies(d.tier)}p'),
            color: const Color(0xFF7FDBFF),
            enabled: d.tier != Tier.mythic,
            onTap: () {
              final r = g.sell(g.you, i);
              if (!r.ok) return _toast(r.msg);
              Sfx.sell();
              _narr.note('Sold one ${d.name}.');
              if (g.you.cells[i].isEmpty) setState(() => selected = null);
            },
          ),
          ActionBtn(
            label: 'SHAKE',
            sub: d.tier == Tier.mythic ? 'never' : (rl > 0 ? '$rl leaf' : '${rp}p'),
            color: const Color(0xFFC77DFF),
            enabled: d.tier != Tier.mythic,
            onTap: () {
              final r = g.reroll(g.you, i);
              if (!r.ok) return _toast(r.msg);
              if (r.unit != null) _narr.note('Shaken into ${r.unit!.name}, ${r.unit!.tier.label}.');
              if (g.you.cells[i].isEmpty) setState(() => selected = null);
            },
          ),
          if (g.partner != null)
            ActionBtn(
              label: 'GIVE',
              sub: 'to $kPartnerName',
              color: const Color(0xFF9BE15D),
              onTap: () {
                final r = g.gift(i);
                if (!r.ok) return _toast(r.msg);
                Sfx.click();
                _narr.note('Gave one ${d.name} to $kPartnerName.');
                if (g.you.cells[i].isEmpty) setState(() => selected = null);
              },
            ),
        ]),
      ]),
    );
  }

  Widget _controls(bool wide) {
    final cost = g.summonCost(g.you);
    final canAfford = g.you.pennies >= cost && g.you.hasEmptyCell;
    final craftable = kRecipes.keys.where((m) => g.canCraft(g.you, m)).length;
    return Container(
      color: Pal.panel,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: SummonButton(cost: cost, enabled: canAfford, onTap: _summon, glow: tut == 1),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: SmallCtl(
              icon: Icons.eco,
              label: 'LEAVES',
              color: Pal.leaf,
              badge: g.you.leaves > 0 ? '${g.you.leaves}' : null,
              onTap: () => _sheet(_gambleSheet)),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: SmallCtl(icon: Icons.build_rounded, label: 'GREASE', color: const Color(0xFFFFA62B), onTap: () => _sheet(_upgradeSheet)),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: SmallCtl(
              icon: Icons.auto_awesome,
              label: 'MYTHICS',
              color: Pal.danger,
              badge: craftable > 0 ? '!' : null,
              onTap: () => _sheet(_mythicSheet)),
        ),
      ]),
    );
  }

  Widget _sidePanel() {
    return Container(
      color: Pal.panel,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(10), children: [
            if (selected != null && !g.you.cells[selected!].isEmpty) ...[
              ClipRRect(borderRadius: BorderRadius.circular(10), child: _selectionPanel()),
              const SizedBox(height: 10),
            ],
            _sectionTitle('READ THE LEAVES'),
            _gambleSheet(),
            const SizedBox(height: 10),
            _sectionTitle('ELBOW GREASE'),
            _upgradeSheet(),
            const SizedBox(height: 10),
            _sectionTitle('MYTHIC RECIPES'),
            _mythicSheet(),
            if (g.partner != null) ...[
              const SizedBox(height: 10),
              _brendaCard(),
            ],
            const SizedBox(height: 8),
            const Text('Keys: Space summon · M merge selected · F speed · P pause · Enter next tip',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        _controls(true),
      ]),
    );
  }

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
      );

  Widget _brendaCard() {
    final b = g.partner!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Pal.panel2, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const CircleAvatar(backgroundColor: Color(0xFFFFB3E1), child: Text('B', style: TextStyle(fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$kPartnerName: ${b.unitCount} figurines, ${b.pennies}p, ${g.sideDps(b).toStringAsFixed(0)} dps',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ]),
    );
  }

  void _sheet(Widget Function() body) {
    Sfx.click();
    showModalBottomSheet(
      context: context,
      backgroundColor: Pal.panel,
      barrierColor: Colors.black26,
      constraints: const BoxConstraints(maxWidth: 520),
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: frame,
        builder: (_, _, _) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 18), child: body()),
        ),
      ),
    );
  }

  Widget _gambleSheet() {
    final p = g.you;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('You have ${p.leaves} tea leaves. Madame Vex\'s cup decides.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 6),
      for (final o in kGambles)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: WideBtn(
            title: '${o.tier.label} figurine',
            sub: '${(o.chance * 100).round()}% chance · ${o.cost} leaf${o.cost > 1 ? 'es' : ''}',
            color: Color(o.tier.color),
            enabled: p.leaves >= o.cost,
            onTap: () {
              final r = g.gamble(p, o);
              Sfx.gamble(r.ok);
              if (r.ok) {
                _showBanner('THE LEAVES SAY YES', r.unit!.name);
                _narr.note('The leaves say yes: ${r.unit!.name}, ${r.unit!.tier.label}.');
              } else {
                toast = r.msg;
                toastT = 1.6;
                _narr.note(r.msg);
              }
            },
          ),
        ),
    ]);
  }

  Widget _upgradeSheet() {
    final p = g.you;
    final odds = summonOdds(p.luck);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var gi = 0; gi < 3; gi++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: WideBtn(
            title: '${kUpgradeGroupNames[gi]}  Lv ${p.upg[gi]}',
            sub: p.upg[gi] >= kMaxUpgrade ? 'Maxed' : '+${(kUpgradeStep * 100).round()}% damage · ${upgradeCost(gi, p.upg[gi])}p',
            color: Color(Tier.values[gi == 0 ? 1 : gi == 1 ? 2 : 3].color),
            enabled: p.upg[gi] < kMaxUpgrade && p.pennies >= upgradeCost(gi, p.upg[gi]),
            onTap: () {
              final r = g.upgrade(p, gi);
              r.ok ? Sfx.upgrade() : _toast(r.msg);
              if (r.ok) _narr.note('${kUpgradeGroupNames[gi]} now level ${p.upg[gi]}.');
            },
          ),
        ),
      WideBtn(
        title: 'Lucky Penny  Lv ${p.luck}',
        sub: p.luck >= kMaxLuck
            ? 'Maxed · odds ${odds.map((o) => o.toStringAsFixed(0)).join('/')}%'
            : 'Better summon odds · ${luckUpgradeCost(p.luck)}p · now ${odds.map((o) => o.toStringAsFixed(1)).join('/')}%',
        color: Pal.neon,
        enabled: p.luck < kMaxLuck && p.pennies >= luckUpgradeCost(p.luck),
        onTap: () {
          final r = g.upgradeLuck(p);
          r.ok ? Sfx.upgrade() : _toast(r.msg);
          if (r.ok) _narr.note('Lucky Penny now level ${p.luck}.');
        },
      ),
      const SizedBox(height: 6),
      _unions(),
    ]);
  }

  Widget _unions() {
    final on = g.you.activeUnions();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in kUnionRules.entries)
        Tooltip(
          message: '3 different ${e.key} figurines: ${e.value}',
          child: Chip(
            visualDensity: VisualDensity.compact,
            backgroundColor: on.contains(e.key) ? const Color(0xFF3B6B2A) : const Color(0xFF2A2440),
            label: Text(on.contains(e.key) ? '${e.key}: ${e.value}' : e.key,
                style: TextStyle(color: on.contains(e.key) ? Colors.white : Colors.white54, fontSize: 11)),
          ),
        ),
    ]);
  }

  Widget _mythicSheet() {
    final p = g.you;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in kRecipes.entries)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Pal.panel2, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            UnitIcon(kUnitById[e.key]!, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kUnitById[e.key]!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Wrap(spacing: 4, runSpacing: 2, children: [
                  for (final id in e.value)
                    Text(
                      '${p.countOf(id) > 0 ? '✓' : '•'} ${kUnitById[id]!.name}',
                      style: TextStyle(
                          color: p.countOf(id) > 0 ? Pal.leaf : Color(kUnitById[id]!.tier.color).withValues(alpha: 0.7), fontSize: 11),
                    ),
                ]),
              ]),
            ),
            ActionBtn(
              label: 'BUILD',
              sub: '',
              color: Pal.danger,
              enabled: g.canCraft(p, e.key),
              onTap: () {
                final r = g.craft(p, e.key);
                if (!r.ok) _toast(r.msg);
              },
            ),
          ]),
        ),
    ]);
  }

  Widget _tutorialCard(bool wide) {
    final s = kTutorial[tut];
    return Positioned(
      left: 12,
      right: wide ? 372 : 12,
      top: wide ? 70 : 64,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: const Color(0xF2261E42),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tut + 1}/${kTutorial.length}  ${s.title}',
                    style: const TextStyle(color: Pal.neon, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 6),
                Text(s.body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                const SizedBox(height: 10),
                Row(children: [
                  Flexible(
                    child: TextButton(
                      onPressed: () => setState(() {
                        tut = -1;
                        widget.meta.tutorialDone = true;
                        widget.onSave();
                      }),
                      child: const Text('Skip tutorial', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const Spacer(),
                  if (_tutCanNext)
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Pal.neon, foregroundColor: Pal.ink),
                      onPressed: _tutNext,
                      child: Text(tut == kTutorial.length - 1 ? 'Let\'s go' : 'Next', style: const TextStyle(fontWeight: FontWeight.w900)),
                    )
                  else
                    Text(s.wait == 'summon' ? 'Summons: $_tutSummons/3' : '',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('PAUSED', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const SizedBox(height: 6),
            Text('${g.cfg.mode == GameMode.coop ? 'Co-op with $kPartnerName' : 'Solo'} · ${g.cfg.difficulty.label}',
                style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 18),
            MenuButton(label: 'Resume', onTap: () => setState(() => paused = false)),
            MenuButton(
                label: 'Sound: ${Sfx.sound ? 'on' : 'off'}',
                onTap: () => setState(() {
                      Sfx.sound = !Sfx.sound;
                      widget.meta.sound = Sfx.sound;
                      widget.onSave();
                    })),
            MenuButton(
                label: 'Music: ${Sfx.music ? 'on' : 'off'}',
                onTap: () => setState(() {
                      Sfx.setMusic(!Sfx.music);
                      widget.meta.music = Sfx.music;
                      widget.onSave();
                    })),
            MenuButton(
                label: 'Screen shake: ${widget.meta.shake ? 'on' : 'off'}',
                onTap: () => setState(() {
                      widget.meta.shake = !widget.meta.shake;
                      widget.onSave();
                    })),
            MenuButton(
                label: 'Give up',
                danger: true,
                onTap: () {
                  setState(() {
                    paused = false;
                    g.status = GameStatus.lost;
                    g.endReason = 'You locked up early and went home.';
                  });
                }),
          ]),
        ),
      ),
    );
  }

  Widget _endOverlay() {
    final won = g.status == GameStatus.won;
    final s = summary;
    final st = g.you.stats;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(won ? 'THE PIER IS SAVED' : (g.endless && g.wave > kFinalWave ? 'OFF SEASON OVER' : 'CLOSED FOR THE SEASON'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: won ? Pal.neon : Pal.danger, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(g.endReason, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  StatTile('Wave', '${g.wave}${s?.newBest == true ? ' (best!)' : ''}'),
                  StatTile('Bosses', '${g.bossesKilled}'),
                  StatTile('Kills', '${st.kills}'),
                  StatTile('Merges', '${st.merges}'),
                  StatTile('Mythics', '${st.mythics}'),
                  StatTile('Time', '${(g.time / 60).floor()}m ${(g.time % 60).floor()}s'),
                ]),
                const SizedBox(height: 16),
                if (s != null) ...[
                  Text('+${s.seaGlass} sea glass', style: const TextStyle(color: Color(0xFF7FDBFF), fontSize: 20, fontWeight: FontWeight.w900)),
                  for (final m in s.newMissions)
                    Text('Job done: ${m.name} (+${m.reward})', style: const TextStyle(color: Pal.leaf, fontSize: 13)),
                  for (final u in s.unlocks) Text(u, style: const TextStyle(color: Pal.neon, fontSize: 14, fontWeight: FontWeight.w900)),
                ],
                const SizedBox(height: 18),
                if (won)
                  MenuButton(
                      label: 'Keep going (Endless)',
                      onTap: () => setState(() {
                            g.goEndless();
                            _ended = false;
                          })),
                MenuButton(
                    label: 'Play again',
                    onTap: () => setState(() {
                          _newGame();
                        })),
                MenuButton(label: 'Back to the arcade', onTap: () => Navigator.of(context).pop()),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
