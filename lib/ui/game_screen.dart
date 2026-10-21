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
  TutStep(
    'Welcome to Grimley Pier',
    'Last night of the season, and things are climbing out of the sea. They walk the boardwalk round and round. If $kLaneLimit are on the pier at once, it\'s over.',
    'next',
  ),
  TutStep(
    'Feed the machine',
    'Tap SUMMON. Every penny in the Oracle-O-Matic gives you a random figurine, and they fight for you. Summon three.',
    'summon',
  ),
  TutStep(
    'Three of a kind',
    'Same figurines stack, three to a cell. Tap a full stack and press MERGE, right under it, to squash them into one random figurine from the next tier up. Merging is how you get strong.',
    'next',
  ),
  TutStep(
    'Move them about',
    'Drag a figurine onto another cell to swap them. Cells next to the boardwalk see the most action, so put your best ones there.',
    'next',
  ),
  TutStep(
    'Luck and grease',
    'Tea leaves come every fifth wave and from bosses. GAMBLE them for rare figurines. UPGRADE makes a whole tier hit harder. MYTHICS shows the recipes for the four legends of the pier.',
    'next',
  ),
  TutStep(
    'Bosses',
    'Every 10th wave a boss turns up, and you have $kBossSeconds seconds to get rid of it. Wave $kFinalWave brings the level\'s final boss. Beat it and the next stretch of coast opens. Good luck, love.',
    'next',
  ),
];

class GameScreen extends StatefulWidget {
  final MetaSave meta;
  final GameMode mode;
  final Difficulty difficulty;
  final bool tutorial;
  final VoidCallback onSave;

  /// The level to play. Null means the furthest level reached.
  final int? level;
  const GameScreen({
    super.key,
    required this.meta,
    required this.mode,
    required this.difficulty,
    required this.onSave,
    this.tutorial = false,
    this.level,
  });
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late Game g;
  late int _level = widget.level ?? widget.meta.levelReached;
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
  static const _swapHere = CustomSemanticsAction(
    label: 'Swap with the selected spot',
  );

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
    g = Game(
      widget.meta.configFor(
        widget.mode,
        widget.difficulty,
        DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        lvl: _level,
      ),
    );
    brenda = g.partner == null
        ? null
        : Bot(g, g.partner!, thinkEvery: 0.9, skill: 0.9, chatty: true);
    if (g.partner != null) {
      g.say(
        kPartnerName,
        'Right, love. You take the bottom, I\'ll take the top. Mind the crabs.',
      );
    }
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

  bool get _tutBlocking =>
      tut >= 0 && tut < kTutorial.length && kTutorial[tut].wait == 'next';

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
    shake = sh > 0
        ? Offset((_r.nextDouble() - 0.5) * sh, (_r.nextDouble() - 0.5) * sh)
        : Offset.zero;
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
        SemanticsService.sendAnnouncement(
          View.of(context),
          s.text,
          TextDirection.ltr,
          assertiveness: s.urgent
              ? Assertiveness.assertive
              : Assertiveness.polite,
        );
      }
    }
    frame.value++;
    setState(() {});
  }

  bool _mine(Fx f) =>
      g.cfg.mode == GameMode.solo || f.y > g.field.boardOrigin(0).y - 0.2;

  void _consumeFx() {
    for (final f in g.fx) {
      switch (f.type) {
        case FxType.shot:
        case FxType.beam:
          if (vfx.length < 380) {
            vfx.add(
              VisFx(
                f.type,
                f.x,
                f.y,
                x2: f.x2,
                y2: f.y2,
                color: Color(f.color),
                size: f.size,
                life: f.type == FxType.beam ? 0.22 : 0.16,
              ),
            );
          }
          Sfx.hit(t);
        case FxType.hit:
          vfx.add(
            VisFx(
              f.type,
              f.x,
              f.y,
              color: Color(f.color),
              text: f.text,
              size: f.size,
              life: 0.7,
            ),
          );
        case FxType.kill:
          final n = f.size >= 3 ? 24 : 6;
          for (var i = 0; i < n && vfx.length < 450; i++) {
            final a = _r.nextDouble() * math.pi * 2;
            final sp = (0.6 + _r.nextDouble() * 1.4) * (f.size >= 3 ? 2 : 1);
            vfx.add(
              VisFx(
                FxType.kill,
                f.x,
                f.y,
                vx: math.cos(a) * sp,
                vy: math.sin(a) * sp,
                color: Color(f.color),
                size: f.size >= 3 ? 2 : 1,
                life: 0.45 + _r.nextDouble() * 0.3,
              ),
            );
          }
          Sfx.kill(t, f.size >= 3);
          if (f.size >= 3) shakeAmt += 14;
        case FxType.summon:
        case FxType.merge:
        case FxType.mythic:
          vfx.add(
            VisFx(
              f.type,
              f.x,
              f.y,
              color: Color(f.color),
              size: f.size,
              life: f.type == FxType.mythic ? 1.2 : 0.6,
            ),
          );
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
          _showBanner(
            'WAVE ${g.wave}: ${f.text.toUpperCase()}',
            bossForWave(g.wave).mechText,
            secs: 3.5,
          );
          Sfx.boss();
        case FxType.shake:
          shakeAmt += f.size * 10;
        case FxType.text:
          vfx.add(
            VisFx(
              f.type,
              f.x,
              f.y,
              color: Color(f.color),
              text: f.text,
              size: f.size,
              life: 1.0,
            ),
          );
        case FxType.miss:
          if (vfx.length < 380) {
            vfx.add(VisFx(f.type, f.x, f.y, color: Colors.white, life: 0.5));
          }
        case FxType.pulse:
          vfx.add(
            VisFx(
              f.type,
              f.x,
              f.y,
              color: Color(f.color),
              size: f.size,
              life: 0.4,
            ),
          );
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
    _narr.note(
      'Summoned ${r.unit!.name}, ${r.unit!.tier.label}.',
      kind: 'summon',
    );
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
    setState(
      () => selected = (selected == hit.$2 || g.you.cells[hit.$2].isEmpty)
          ? null
          : hit.$2,
    );
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
    setState(
      () => selected = (selected == i || g.you.cells[i].isEmpty) ? null : i,
    );
    if (selected == i) {
      _narr.note(
        'Selected. ${cellLabel(g, i)} Merge, sell, shake and give are just under it.',
      );
    }
  }

  bool get _tutCanNext =>
      tut >= 0 &&
      tut < kTutorial.length &&
      (kTutorial[tut].wait == 'next' ||
          (kTutorial[tut].wait == 'summon' && _tutSummons >= 3));

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
    if ((k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter) &&
        _tutCanNext) {
      return _tutNext();
    }
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyS) {
      _summon();
    }
    if (k == LogicalKeyboardKey.keyP || k == LogicalKeyboardKey.escape) {
      setState(() => paused = !paused);
    }
    if (k == LogicalKeyboardKey.keyM &&
        selected != null &&
        g.canMerge(g.you, selected!)) {
      _merge(selected!);
    }
    if (k == LogicalKeyboardKey.keyF) {
      setState(() => speed = speed == 1 ? 2 : 1);
    }
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Vx.bgBottom,
      body: KeyboardListener(
        focusNode: _keysFocus,
        autofocus: true,
        onKeyEvent: _keys,
        child: FairgroundBackdrop(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                // One column everywhere. On a wide screen it sits in the middle
                // like an arcade cabinet, with the pier lights either side.
                final colW = math.min(c.maxWidth, 620.0);
                return Stack(
                  children: [
                    if (c.maxWidth > colW + 40)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _CabinetSides()),
                        ),
                      ),
                    Center(
                      child: SizedBox(
                        width: colW,
                        child: Column(
                          children: [
                            _hud(),
                            if (g.boss != null) _bossBar(),
                            Expanded(child: _fieldArea()),
                            _controls(),
                          ],
                        ),
                      ),
                    ),
                    if (tut >= 0 && tut < kTutorial.length) _tutorialCard(),
                    if (paused && !_ended) _pauseOverlay(),
                    if (_ended) _endOverlay(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundBtn({
    required Widget child,
    required VoidCallback onTap,
    required String label,
    Tone tone = Tone.blue,
  }) => Tooltip(
    message: label,
    child: Chunky(
      tone: tone,
      width: 44,
      height: 44,
      radius: 14,
      padding: EdgeInsets.zero,
      semantics: label,
      onTap: onTap,
      child: child,
    ),
  );

  Widget _hud() {
    final p = g.you;
    final lc = g.laneCount;
    final timer = g.boss != null ? g.bossTimer : g.waveTimer;
    final waveLabel = g.wave == 0
        ? 'GET READY'
        : (g.endless ? 'ENDLESS ${g.wave}' : 'WAVE ${g.wave}/$kFinalWave');
    final hot = g.boss != null && timer < 15;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Vx.panelTop, Vx.panelBottom],
        ),
        border: Border(bottom: BorderSide(color: Vx.ink, width: 3)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Expanded(
            // One readable line for the whole bar, built from whole seconds and
            // counts, so it changes about once a second, not every frame.
            child: Semantics(
              container: true,
              label: hudLabel(g),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(waveLabel, style: display(20, w: 2, spacing: 1)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: hot ? Tone.red.bottom : Vx.wellDeep,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Vx.ink, width: 2),
                          ),
                          child: Text(
                            '${timer.ceil()}s',
                            style: display(14, w: 1.2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          levelDef(g.cfg.level).name.toUpperCase(),
                          style: body(
                            11,
                            color: Vx.textDim,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  LaneMeter(count: lc, limit: kLaneLimit),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Pennies and leaves are already in the bar's label.
          ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CurrencyChip(
                  icon: Icons.circle,
                  color: Pal.penny,
                  value: '${p.pennies}',
                  sprite: 'i_penny',
                ),
                const SizedBox(height: 3),
                CurrencyChip(
                  icon: Icons.eco,
                  color: Pal.leaf,
                  value: '${p.leaves}',
                  sprite: 'i_leaf',
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _roundBtn(
            label: speed == 1 ? 'Speed up (F)' : 'Normal speed (F)',
            tone: speed == 2 ? Tone.yellow : Tone.blue,
            onTap: () => setState(() => speed = speed == 1 ? 2 : 1),
            child: Text(
              '${speed}x',
              style: display(
                17,
                stroke: (speed == 2 ? Tone.yellow : Tone.blue).lip,
                w: 1.6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _roundBtn(
            label: 'Pause (P)',
            onTap: () => setState(() => paused = true),
            child: const Icon(
              Icons.pause_rounded,
              color: Colors.white,
              size: 26,
              shadows: [Shadow(color: Vx.ink, offset: Offset(0, 2))],
            ),
          ),
        ],
      ),
    );
  }

  /// One twin's health bar. A dead twin shows an empty bar.
  Widget _twinBar(Enemy b) {
    final frac = b.dead ? 0.0 : (b.hp / b.maxHp).clamp(0.0, 1.0);
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Vx.ink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: frac,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF8473), Color(0xFFC22B3A)],
                  ),
                ),
              ),
            ),
            if (!b.dead && b.shield > 0)
              FractionallySizedBox(
                widthFactor: (b.shield / b.maxHp).clamp(0.0, 1.0),
                child: Container(color: const Color(0xCC9EE7FF)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bossBar() {
    final b = g.boss!;
    final twins = g.bosses.isEmpty ? [b] : g.bosses;
    final last = g.wave == kFinalWave && !g.endless;
    return Semantics(
      container: true,
      label: bossLabel(g),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5A1630), Color(0xFF2A0F22)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Vx.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF16060F), offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            SpriteImg('b_${b.boss!.id}', size: 40),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${last ? 'FINAL BOSS · ' : ''}${twins.length > 1 ? '2 × ' : ''}${b.name.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: display(
                            15,
                            stroke: const Color(0xFF16060F),
                            w: 1.6,
                          ),
                        ),
                      ),
                      Text(
                        '${g.bossTimer.ceil()}s',
                        style: display(
                          15,
                          color: g.bossTimer < 15
                              ? const Color(0xFFFF8473)
                              : Colors.white,
                          w: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      for (var i = 0; i < twins.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(child: _twinBar(twins[i])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.boss!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(10, color: const Color(0xFFFFB3C1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldArea() {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _geo = FieldGeom(g.field, size);
        final chat = g.chat.isNotEmpty && g.time - g.chat.last.at < 4.5
            ? g.chat.last
            : null;
        if (g.chat.length != _lastChat) _lastChat = g.chat.length;
        final geo = _geo!;
        final boards = [
          boardSummary(g, g.you, owner: 'Your'),
          if (g.partner != null)
            boardSummary(g, g.partner!, owner: "$kPartnerName's"),
        ].join(' ');
        return Stack(
          children: [
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
                onPanUpdate: (d) =>
                    dragFrom != null ? dragPos = d.localPosition : null,
                onPanEnd: (_) => _panEnd(),
                onPanCancel: _panEnd,
                child: CustomPaint(
                  size: size,
                  painter: FieldPainter(
                    g,
                    vfx,
                    t,
                    selected: selected,
                    dragFrom: dragFrom,
                    dragPos: dragPos,
                    shake: shake,
                    freezeFlash: freezeFlash,
                    tutorialHighlight: tut == 2 ? _firstMergeable() : -1,
                  ),
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
                              _narr.note(
                                'Swapped ${spotName(from)} and ${spotName(i)}.',
                              );
                              setState(() => selected = i);
                            },
                          }
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
            if (selected != null && !g.you.cells[selected!].isEmpty)
              _selectionPopup(geo, size),
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
                    child: SpeechBubble(speaker: chat.speaker, text: chat.text),
                  ),
                ),
              ),
            // The banner and toast are spoken as announcements, so the tree skips
            // them rather than growing and shrinking a node under the reader.
            if (bannerT > 0 && banner != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Center(
                      child: BigBanner(
                        title: banner!,
                        sub: bannerSub ?? '',
                        k: bannerT,
                      ),
                    ),
                  ),
                ),
              ),
            if (toastT > 0 && toast != null)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Center(child: ToastPill(text: toast!)),
                  ),
                ),
              ),
          ],
        );
      },
    );
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

  /// Merge and Sell (and Shake, and Give in co-op) on a little plate that
  /// hangs right under the figurine you picked, Lucky Defense style. It flips
  /// above the figurine when there is no room underneath.
  Widget _selectionPopup(FieldGeom geo, Size size) {
    final i = selected!;
    final cell = g.you.cells[i];
    final d = cell.def!;
    final (rp, rl) = g.rerollCost(d.tier);
    final ingredientOf = [
      for (final e in kRecipes.entries)
        if (e.value.contains(d.id)) kUnitById[e.key]!.name,
    ];
    final r = _cellRect(geo, i);
    const w = 248.0;
    const h = 112.0;
    final below = r.bottom + h + 4 <= size.height;
    final left = (r.center.dx - w / 2).clamp(
      4.0,
      math.max(4.0, size.width - w - 4),
    );
    final top = below ? r.bottom + 2 : math.max(0.0, r.top - h - 2);
    final tone = toneForTier(d.tier.index);
    final merge = g.canMerge(g.you, i);
    return Positioned(
      left: left.toDouble(),
      top: top,
      width: w,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Vx.panelTop, Vx.panelBottom],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Vx.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tone.bottom,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Vx.ink, width: 1.5),
                  ),
                  child: Text(
                    d.tier.label.toUpperCase(),
                    style: display(10, stroke: tone.lip, w: 1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Tooltip(
                    message:
                        '${d.desc}${ingredientOf.isEmpty ? '' : '\nIngredient for ${ingredientOf.join(', ')}'}',
                    child: Text(
                      '${d.name} ×${cell.units.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(15, w: 1.5),
                    ),
                  ),
                ),
                Text(
                  '${(d.dps * g.dmgMult(g.you, d)).toStringAsFixed(0)} dps',
                  style: body(11, color: Vx.textDim, weight: FontWeight.w900),
                ),
              ],
            ),
            if (ingredientOf.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mythic ingredient: ${ingredientOf.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(10, color: const Color(0xFFFFB3C1)),
                ),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Chunky.label(
                    'MERGE',
                    sub: d.tier.index < 3
                        ? (merge
                              ? '3 → ${Tier.values[d.tier.index + 1].label}'
                              : '${cell.units.length}/3')
                        : 'top tier',
                    tone: Tone.green,
                    height: 52,
                    size: 18,
                    enabled: merge,
                    semantics: 'Merge${merge ? '' : ', not available'}',
                    onTap: merge ? () => _merge(i) : null,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 2,
                  child: Chunky.label(
                    'SELL',
                    sub: d.tier == Tier.mythic
                        ? 'never'
                        : (sellLeaves(d.tier) > 0
                              ? '+${sellLeaves(d.tier)} leaf'
                              : '+${sellPennies(d.tier)}p'),
                    tone: Tone.blue,
                    height: 52,
                    size: 16,
                    enabled: d.tier != Tier.mythic,
                    semantics:
                        'Sell one${d.tier == Tier.mythic ? ', not available' : ''}',
                    onTap: d.tier == Tier.mythic
                        ? null
                        : () {
                            final r = g.sell(g.you, i);
                            if (!r.ok) return _toast(r.msg);
                            Sfx.sell();
                            _narr.note('Sold one ${d.name}.');
                            if (g.you.cells[i].isEmpty) {
                              setState(() => selected = null);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 5),
                _miniBtn(
                  icon: Icons.casino_rounded,
                  tone: Tone.purple,
                  label: d.tier == Tier.mythic
                      ? 'Shake, not available'
                      : 'Shake into another ${d.tier.label}, ${rl > 0 ? '$rl leaf' : '$rp pennies'}',
                  enabled: d.tier != Tier.mythic,
                  onTap: () {
                    final r = g.reroll(g.you, i);
                    if (!r.ok) return _toast(r.msg);
                    if (r.unit != null) {
                      _narr.note(
                        'Shaken into ${r.unit!.name}, ${r.unit!.tier.label}.',
                      );
                    }
                    if (g.you.cells[i].isEmpty) setState(() => selected = null);
                  },
                ),
                if (g.partner != null) ...[
                  const SizedBox(width: 5),
                  _miniBtn(
                    icon: Icons.volunteer_activism_rounded,
                    tone: Tone.teal,
                    label: 'Give one to $kPartnerName',
                    onTap: () {
                      final r = g.gift(i);
                      if (!r.ok) return _toast(r.msg);
                      Sfx.click();
                      _narr.note('Gave one ${d.name} to $kPartnerName.');
                      if (g.you.cells[i].isEmpty) {
                        setState(() => selected = null);
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required Tone tone,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) => Tooltip(
    message: label,
    child: Chunky(
      tone: tone,
      width: 40,
      height: 52,
      radius: 12,
      padding: EdgeInsets.zero,
      enabled: enabled,
      semantics: label,
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
        shadows: const [Shadow(color: Vx.ink, offset: Offset(0, 2))],
      ),
    ),
  );

  /// The bottom bar: Gamble, Summon (the big one), Upgrade and Mythics.
  Widget _controls() {
    final cost = g.summonCost(g.you);
    final canAfford = g.you.pennies >= cost && g.you.hasEmptyCell;
    final craftable = kRecipes.keys.where((m) => g.canCraft(g.you, m)).length;
    final canUpgrade = [
      for (var gi = 0; gi < 3; gi++)
        g.you.upg[gi] < kMaxUpgrade &&
            g.you.pennies >= upgradeCost(gi, g.you.upg[gi]),
    ].contains(true);
    Widget tile(Widget w) => Expanded(flex: 3, child: Center(child: w));
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Vx.panelBottom, Vx.wellDeep],
        ),
        border: Border(top: BorderSide(color: Vx.ink, width: 3)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          tile(
            SmallCtl(
              icon: Icons.eco,
              sprite: 'i_cup',
              label: 'GAMBLE',
              color: Pal.leaf,
              tone: Tone.green,
              badge: g.you.leaves > 0 ? '${g.you.leaves}' : null,
              onTap: () => _sheet('Read the Leaves', Tone.green, _gambleSheet),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: SummonButton(
              cost: cost,
              enabled: canAfford,
              onTap: _summon,
              glow: tut == 1,
            ),
          ),
          const SizedBox(width: 6),
          tile(
            SmallCtl(
              icon: Icons.build_rounded,
              sprite: 'i_upgrade',
              label: 'UPGRADE',
              color: const Color(0xFFFFA62B),
              tone: Tone.yellow,
              badge: canUpgrade ? '↑' : null,
              onTap: () => _sheet('Elbow Grease', Tone.yellow, _upgradeSheet),
            ),
          ),
          const SizedBox(width: 6),
          tile(
            SmallCtl(
              icon: Icons.auto_awesome,
              sprite: 'i_book',
              label: 'MYTHICS',
              color: Pal.danger,
              tone: Tone.purple,
              badge: craftable > 0 ? '!' : null,
              onTap: () => _sheet('Mythic Recipes', Tone.purple, _mythicSheet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brendaCard() {
    final b = g.partner!;
    return Well(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB3E1),
              shape: BoxShape.circle,
              border: Border.all(color: Vx.ink, width: 2),
            ),
            child: Text(
              'B',
              style: display(18, stroke: const Color(0xFFB0457F), w: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$kPartnerName: ${b.unitCount} figurines, ${b.pennies}p, ${g.sideDps(b).toStringAsFixed(0)} dps',
              style: body(12),
            ),
          ),
        ],
      ),
    );
  }

  void _sheet(String title, Tone tone, Widget Function() content) {
    Sfx.click();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 520),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: GameDialogFrame(
          title: title,
          tone: tone,
          onClose: () => Navigator.of(ctx).pop(),
          child: ValueListenableBuilder<int>(
            valueListenable: frame,
            builder: (_, _, _) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.58,
              ),
              child: SingleChildScrollView(child: content()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gambleSheet() {
    final p = g.you;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You have ${p.leaves} tea leaves. Madame Vex\'s cup decides.',
          textAlign: TextAlign.center,
          style: body(12.5, color: Vx.textDim),
        ),
        const SizedBox(height: 6),
        for (final o in kGambles)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: WideBtn(
              title: '${o.tier.label} figurine',
              sub:
                  '${(o.chance * 100).round()}% chance · ${o.cost} leaf${o.cost > 1 ? 'es' : ''}',
              color: Color(o.tier.color),
              enabled: p.leaves >= o.cost,
              onTap: () {
                final r = g.gamble(p, o);
                Sfx.gamble(r.ok);
                if (r.ok) {
                  _showBanner('THE LEAVES SAY YES', r.unit!.name);
                  _narr.note(
                    'The leaves say yes: ${r.unit!.name}, ${r.unit!.tier.label}.',
                  );
                } else {
                  toast = r.msg;
                  toastT = 1.6;
                  _narr.note(r.msg);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _upgradeSheet() {
    final p = g.you;
    final odds = summonOdds(p.luck);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var gi = 0; gi < 3; gi++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: WideBtn(
              title: '${kUpgradeGroupNames[gi]}  Lv ${p.upg[gi]}',
              sub: p.upg[gi] >= kMaxUpgrade
                  ? 'Maxed'
                  : '+${(kUpgradeStep * 100).round()}% damage · ${upgradeCost(gi, p.upg[gi])}p',
              color: Color(
                Tier
                    .values[gi == 0
                        ? 1
                        : gi == 1
                        ? 2
                        : 3]
                    .color,
              ),
              enabled:
                  p.upg[gi] < kMaxUpgrade &&
                  p.pennies >= upgradeCost(gi, p.upg[gi]),
              onTap: () {
                final r = g.upgrade(p, gi);
                r.ok ? Sfx.upgrade() : _toast(r.msg);
                if (r.ok) {
                  _narr.note(
                    '${kUpgradeGroupNames[gi]} now level ${p.upg[gi]}.',
                  );
                }
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
      ],
    );
  }

  Widget _unions() {
    final on = g.you.activeUnions();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in kUnionRules.entries)
          Tooltip(
            message: '3 different ${e.key} figurines: ${e.value}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: on.contains(e.key) ? Tone.green.bottom : Vx.wellDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Vx.ink, width: 2),
              ),
              child: Text(
                on.contains(e.key) ? '${e.key}: ${e.value}' : e.key,
                style: body(
                  11,
                  color: on.contains(e.key) ? Colors.white : Vx.textDim,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mythicSheet() {
    final p = g.you;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in kRecipes.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Well(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  UnitIcon(kUnitById[e.key]!, size: 44),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kUnitById[e.key]!.name,
                          style: display(15, w: 1.4),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            for (final id in e.value)
                              Text(
                                '${p.countOf(id) > 0 ? '✓' : '•'} ${kUnitById[id]!.name}',
                                style: body(
                                  11,
                                  color: p.countOf(id) > 0
                                      ? Pal.leaf
                                      : Color(kUnitById[id]!.tier.color)
                                            .withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ActionBtn(
                    label: 'BUILD',
                    sub: '',
                    color: Pal.danger,
                    tone: Tone.purple,
                    width: 76,
                    enabled: g.canCraft(p, e.key),
                    onTap: () {
                      final r = g.craft(p, e.key);
                      if (!r.ok) _toast(r.msg);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _tutorialCard() {
    final s = kTutorial[tut];
    return Positioned(
      left: 12,
      right: 12,
      top: 70,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            type: MaterialType.transparency,
            child: GamePanel(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Tone.yellow.bottom,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Vx.ink, width: 2),
                        ),
                        child: Text(
                          '${tut + 1}/${kTutorial.length}',
                          style: display(13, stroke: Tone.yellow.lip, w: 1.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.title, style: display(19, w: 1.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.body, style: body(13.5, height: 1.35)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        child: TextButton(
                          onPressed: () => setState(() {
                            tut = -1;
                            widget.meta.tutorialDone = true;
                            widget.onSave();
                          }),
                          child: Text(
                            'Skip tutorial',
                            overflow: TextOverflow.ellipsis,
                            style: body(13, color: Vx.textDim),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_tutCanNext)
                        Chunky(
                          tone: Tone.green,
                          height: 46,
                          width: 120,
                          onTap: _tutNext,
                          child: Text(
                            tut == kTutorial.length - 1 ? 'Let\'s go' : 'Next',
                            style: display(18, stroke: Tone.green.lip, w: 1.8),
                          ),
                        )
                      else
                        Text(
                          s.wait == 'summon' ? 'Summons: $_tutSummons/3' : '',
                          style: display(15, w: 1.4),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    Widget toggle(String label, bool on, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Chunky(
        tone: on ? Tone.teal : Tone.grey,
        height: 48,
        semantics: '$label: ${on ? 'on' : 'off'}',
        onTap: () => setState(onTap),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: display(
                  17,
                  stroke: (on ? Tone.teal : Tone.grey).lip,
                  w: 1.6,
                ),
              ),
            ),
            Text(
              on ? 'ON' : 'OFF',
              style: display(
                17,
                stroke: (on ? Tone.teal : Tone.grey).lip,
                w: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GameDialogFrame(
              title: 'Paused',
              tone: Tone.blue,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Level ${g.cfg.level} · ${levelDef(g.cfg.level).name}',
                    textAlign: TextAlign.center,
                    style: display(17, w: 1.6),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${g.cfg.mode == GameMode.coop ? 'Co-op with $kPartnerName' : 'Solo'} · ${g.cfg.difficulty.label} · wave ${g.wave}',
                    textAlign: TextAlign.center,
                    style: body(12, color: Vx.textDim),
                  ),
                  if (g.partner != null) ...[
                    const SizedBox(height: 8),
                    _brendaCard(),
                  ],
                  const SizedBox(height: 12),
                  MenuButton(
                    label: 'Resume',
                    primary: true,
                    onTap: () => setState(() => paused = false),
                  ),
                  const SizedBox(height: 6),
                  toggle('Sound', Sfx.sound, () {
                    Sfx.sound = !Sfx.sound;
                    widget.meta.sound = Sfx.sound;
                    widget.onSave();
                  }),
                  toggle('Music', Sfx.music, () {
                    Sfx.setMusic(!Sfx.music);
                    widget.meta.music = Sfx.music;
                    widget.onSave();
                  }),
                  toggle('Screen shake', widget.meta.shake, () {
                    widget.meta.shake = !widget.meta.shake;
                    widget.onSave();
                  }),
                  MenuButton(
                    label: 'Give up',
                    danger: true,
                    onTap: () {
                      setState(() {
                        paused = false;
                        g.status = GameStatus.lost;
                        g.endReason = 'You locked up early and went home.';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _endOverlay() {
    final won = g.status == GameStatus.won;
    final s = summary;
    final st = g.you.stats;
    final lvl = g.cfg.level;
    final endlessOver = g.endless && g.wave > kFinalWave;
    final title = won
        ? 'THE PIER IS SAVED'
        : (endlessOver ? 'OFF SEASON OVER' : 'CLOSED FOR THE SEASON');
    final tone = won || endlessOver ? Tone.yellow : Tone.red;
    final unlockedNext =
        won &&
        s != null &&
        s.unlocks.any((u) => u.startsWith('Level ${lvl + 1} unlocked'));
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (won)
                    const SpriteImg('i_trophy', size: 84)
                  else
                    SpriteImg(
                      'b_${levelDef(lvl).finalBoss}',
                      size: 84,
                      dim: !endlessOver && g.wave < kFinalWave,
                    ),
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: display(
                        30,
                        color: won ? Vx.gold : Colors.white,
                        w: 2.8,
                        spacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level $lvl · ${levelDef(lvl).name}',
                    textAlign: TextAlign.center,
                    style: display(15, color: Vx.textDim, w: 1.4),
                  ),
                  const SizedBox(height: 14),
                  GameDialogFrame(
                    title: won ? 'Level cleared' : 'Last orders',
                    tone: tone,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          g.endReason,
                          textAlign: TextAlign.center,
                          style: body(13, color: Vx.textDim),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            StatTile(
                              'Wave',
                              '${g.wave}${s?.newBest == true ? ' ★' : ''}',
                            ),
                            StatTile('Bosses', '${g.bossesKilled}'),
                            StatTile('Kills', '${st.kills}'),
                            StatTile('Merges', '${st.merges}'),
                            StatTile('Mythics', '${st.mythics}'),
                            StatTile(
                              'Time',
                              '${(g.time / 60).floor()}m ${(g.time % 60).floor()}s',
                            ),
                          ],
                        ),
                        if (s != null) ...[
                          const SizedBox(height: 12),
                          Well(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SpriteImg('i_glass', size: 34),
                                const SizedBox(width: 6),
                                Text(
                                  '+${s.seaGlass} sea glass',
                                  style: display(22, color: Vx.glass, w: 2),
                                ),
                              ],
                            ),
                          ),
                          if (s.newBest) ...[
                            const SizedBox(height: 6),
                            Text(
                              'New best on this level!',
                              textAlign: TextAlign.center,
                              style: display(14, color: Vx.gold, w: 1.4),
                            ),
                          ],
                          for (final m in s.newMissions)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _endLine(
                                'i_book',
                                'Job done: ${m.name}',
                                '+${m.reward}',
                              ),
                            ),
                          for (final u in s.unlocks)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _endLine(
                                u.startsWith('Level') ? 'i_buoy' : 'i_cup',
                                u,
                                null,
                                hot: true,
                              ),
                            ),
                        ],
                        const SizedBox(height: 14),
                        if (won)
                          MenuButton(
                            label: 'Keep going (Endless)',
                            sub: 'No more waves to count. See how far it goes.',
                            primary: true,
                            onTap: () => setState(() {
                              g.goEndless();
                              _ended = false;
                            }),
                          ),
                        MenuButton(
                          label: won ? 'Replay level $lvl' : 'Try again',
                          tone: won ? Tone.blue : Tone.green,
                          onTap: () => setState(() {
                            _newGame();
                          }),
                        ),
                        if (unlockedNext ||
                            (won && widget.meta.levelReached > lvl))
                          MenuButton(
                            label: 'On to level ${lvl + 1}',
                            sub: levelDef(lvl + 1).name,
                            tone: Tone.green,
                            onTap: () => setState(() {
                              _level = lvl + 1;
                              _newGame();
                            }),
                          ),
                        MenuButton(
                          label: 'Back to the arcade',
                          tone: Tone.grey,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _endLine(
    String sprite,
    String text,
    String? tail, {
    bool hot = false,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    decoration: BoxDecoration(
      color: hot ? const Color(0x553DB43A) : Vx.wellDeep,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Vx.ink, width: 2),
    ),
    child: Row(
      children: [
        SpriteImg(sprite, size: 26),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: body(13, color: hot ? Colors.white : Vx.text),
          ),
        ),
        if (tail != null)
          Text(tail, style: display(14, color: Vx.glass, w: 1.2)),
      ],
    ),
  );
}

/// Pier lights down both sides of a wide screen, so the game column looks
/// like it is standing in an arcade rather than floating in a void.
class _CabinetSides extends CustomPainter {
  const _CabinetSides();
  @override
  void paint(Canvas canvas, Size size) {
    final colW = math.min(size.width, 620.0);
    final side = (size.width - colW) / 2;
    final bulb = Paint();
    for (final x0 in [0.0, size.width - side]) {
      final rect = Rect.fromLTWH(x0, 0, side, size.height);
      canvas.drawRect(rect, Paint()..color = const Color(0x22000000));
      final cx = x0 == 0 ? side - 18 : x0 + 18;
      for (var y = 24.0; y < size.height; y += 34) {
        final on = ((y / 34).round() % 3) != 0;
        bulb.color = on ? const Color(0xFFFFE9A8) : const Color(0x66FFE9A8);
        canvas.drawCircle(Offset(cx, y), 5, bulb);
        if (on) {
          canvas.drawCircle(
            Offset(cx, y),
            11,
            Paint()..color = const Color(0x22FFD84A),
          );
        }
      }
      // A rail between the bulbs and the column.
      final rx = x0 == 0 ? side - 4 : x0 + 4;
      canvas.drawLine(
        Offset(rx, 0),
        Offset(rx, size.height),
        Paint()
          ..color = Vx.ink
          ..strokeWidth = 4,
      );
    }
  }

  @override
  bool shouldRepaint(_CabinetSides old) => false;
}
