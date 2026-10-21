// Front of house: the arcade (home), the shift picker, the Back Room, the
// Jobs board, the album and the sea things book.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/data.dart';
import '../game/meta.dart';
import 'art.dart';
import 'game_screen.dart';
import 'widgets.dart';

/// Starts a run and saves when you come back.
Future<void> _startRun(
  BuildContext context,
  MetaSave meta,
  VoidCallback save, {
  required int level,
  bool tutorial = false,
}) async {
  Sfx.unlock();
  Sfx.setMusic(meta.music);
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GameScreen(
        meta: meta,
        mode: meta.lastMode,
        difficulty: meta.nextDifficulty,
        level: level,
        onSave: save,
        tutorial: tutorial || !meta.tutorialDone,
      ),
    ),
  );
  save();
}

/// The page every menu screen sits on: the sea, a header with a back button
/// and your sea glass, and one centred column so desktop doesn't sprawl.
class _Page extends StatelessWidget {
  final String title;
  final MetaSave meta;
  final Widget child;
  final Widget? bottom;
  const _Page({
    required this.title,
    required this.meta,
    required this.child,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Vx.bgBottom,
      body: SeaBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  ScreenHeader(title: title, trailing: _GlassChip(meta)),
                  Expanded(child: child),
                  ?bottom,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final MetaSave meta;
  const _GlassChip(this.meta);
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${meta.seaGlass} sea glass',
    excludeSemantics: true,
    child: CurrencyChip(
      icon: Icons.diamond,
      color: Vx.glass,
      value: '${meta.seaGlass}',
      sprite: 'i_glass',
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: display(15, color: Vx.gold, w: 1.6, spacing: 1),
      ),
    ),
  );
}

/// A small coloured tag, like the price stickers on the prize shelf.
class _Tag extends StatelessWidget {
  final String text;
  final Tone tone;
  const _Tag(this.text, this.tone);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: tone.bottom,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Vx.ink, width: 1.5),
    ),
    child: Text(
      text.toUpperCase(),
      style: display(10.5, stroke: tone.lip, w: 1),
    ),
  );
}

// ============================== HOME ==============================

class HomeScreen extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const HomeScreen({super.key, required this.meta, required this.save});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MetaSave get m => widget.meta;
  late int _lvl = m.levelReached;

  void _save() {
    widget.save();
    if (mounted) setState(() => _lvl = _lvl.clamp(1, m.levelReached));
  }

  Future<void> _go(Widget page) async {
    Sfx.click();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    await _startRun(context, m, widget.save, level: _lvl);
    // A clear moves you on: next time PLAY starts the new level.
    if (mounted) setState(() => _lvl = m.levelReached);
  }

  @override
  Widget build(BuildContext context) {
    final affordable = kMetaUpgrades
        .where(
          (u) =>
              !(m.level(u.id) >= u.max) && m.seaGlass >= u.cost(m.level(u.id)),
        )
        .length;
    final pages = kUnits.where(m.collected).length;
    return Scaffold(
      backgroundColor: Vx.bgBottom,
      body: SeaBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, c) {
                final heroH = (c.maxHeight * 0.34).clamp(150.0, 330.0);
                return Stack(
                  children: [
                    // The painted pier at dusk, fading into the sea.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: heroH + 70,
                      child: ExcludeSemantics(
                        child: ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0, 0.62, 1],
                          ).createShader(r),
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            'assets/title.jpg',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.2),
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                _GlassChip(m),
                                const Spacer(),
                                _SoundBtn(meta: m, save: widget.save),
                              ],
                            ),
                            // Short screens give up sky so PLAY stays above the fold.
                            SizedBox(
                              height: ((c.maxHeight - 600) * 0.6).clamp(
                                12.0,
                                200.0,
                              ),
                            ),
                            _Logo(size: c.maxHeight < 700 ? 50 : 64),
                            const SizedBox(height: 14),
                            _levelCard(),
                            const SizedBox(height: 10),
                            _setup(),
                            const SizedBox(height: 12),
                            Chunky.label(
                              'PLAY',
                              sub: m.tutorialDone
                                  ? 'Level $_lvl · ${m.lastMode == GameMode.coop ? 'with $kPartnerName' : 'solo'} · ${m.nextDifficulty.label}'
                                  : 'First shift: a quick walk round first',
                              tone: Tone.yellow,
                              height: 80,
                              size: 36,
                              semantics: 'Play level $_lvl',
                              onTap: _play,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: SmallCtl(
                                    icon: Icons.storefront,
                                    sprite: 'i_upgrade',
                                    label: 'BACK ROOM',
                                    color: Vx.glass,
                                    tone: Tone.yellow,
                                    badge: affordable > 0
                                        ? '$affordable'
                                        : null,
                                    onTap: () =>
                                        _go(BackRoom(meta: m, save: _save)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SmallCtl(
                                    icon: Icons.assignment,
                                    sprite: 'i_book',
                                    label: 'JOBS',
                                    color: Pal.leaf,
                                    tone: Tone.green,
                                    onTap: () => _go(JobsBoard(meta: m)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SmallCtl(
                                    icon: Icons.collections,
                                    sprite: 'i_trophy',
                                    label: 'ALBUM',
                                    color: Pal.danger,
                                    tone: Tone.purple,
                                    badge: pages > 0 ? '$pages' : null,
                                    onTap: () => _go(Album(meta: m)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SmallCtl(
                                    icon: Icons.set_meal,
                                    sprite: 'i_buoy',
                                    label: 'SEA THINGS',
                                    color: Pal.sea2,
                                    tone: Tone.teal,
                                    onTap: () => _go(Bestiary(meta: m)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SmallCtl(
                                    icon: Icons.map,
                                    sprite: 'i_dice',
                                    label: 'LEVELS',
                                    color: Vx.gold,
                                    tone: Tone.blue,
                                    onTap: () =>
                                        _go(ModeSelect(meta: m, save: _save)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Runs ${m.runs} · Levels cleared ${m.levelReached - 1} · Album pages $pages/${kUnits.length}',
                              textAlign: TextAlign.center,
                              style: body(11.5, color: Vx.textDim),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelCard() {
    final def = levelDef(_lvl);
    final boss = kBossById[def.finalBoss]!;
    final best = m.bestOnLevel(_lvl);
    final cleared = _lvl < m.levelReached;
    Widget arrow(bool left) {
      final on = left ? _lvl > 1 : _lvl < m.levelReached;
      return Chunky(
        tone: on ? Tone.blue : Tone.grey,
        width: 40,
        height: 56,
        radius: 12,
        padding: EdgeInsets.zero,
        enabled: on,
        semantics: left ? 'Previous level' : 'Next level',
        onTap: on
            ? () {
                Sfx.click();
                setState(() => _lvl += left ? -1 : 1);
              }
            : null,
        child: Icon(
          left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          color: Colors.white,
          size: 30,
        ),
      );
    }

    return GamePanel(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          arrow(true),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              container: true,
              label:
                  'Level $_lvl, ${def.name}. ${def.blurb} Final boss ${boss.name}. ${cleared
                      ? 'Cleared.'
                      : best > 0
                      ? 'Best wave $best of $kFinalWave.'
                      : 'Not played yet.'}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Tag('Level $_lvl', Tone.yellow),
                      if (cleared) _Tag('Cleared', Tone.green),
                      if (_lvl == m.levelReached && !cleared)
                        _Tag('Up next', Tone.teal),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(def.name, style: display(24, w: 2.2)),
                  Text(
                    def.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: Vx.textDim, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  ProgressPill(
                    value: cleared ? 1 : best / kFinalWave,
                    label: cleared ? 'CLEARED' : 'BEST WAVE $best/$kFinalWave',
                    color: cleared ? Tone.green.top : Tone.yellow.top,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          ExcludeSemantics(
            child: Column(
              children: [
                SpriteImg('b_${boss.id}', size: 62),
                SizedBox(
                  width: 70,
                  child: Text(
                    boss.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: body(
                      9.5,
                      color: const Color(0xFFFFB3C1),
                      weight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          arrow(false),
        ],
      ),
    );
  }

  Widget _setup() {
    Widget seg(
      String label,
      bool on,
      VoidCallback onTap, {
      bool locked = false,
    }) => Expanded(
      child: Chunky(
        tone: on ? Tone.teal : Tone.grey,
        height: 40,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        enabled: !locked,
        semantics: '$label${on ? ', selected' : ''}${locked ? ', locked' : ''}',
        onTap: locked
            ? null
            : () {
                Sfx.click();
                setState(onTap);
                widget.save();
              },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked)
                const Icon(Icons.lock_rounded, size: 13, color: Colors.white70),
              Text(
                label,
                style: display(
                  14,
                  stroke: (on ? Tone.teal : Tone.grey).lip,
                  w: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        seg(
          'CO-OP',
          m.lastMode == GameMode.coop,
          () => m.lastMode = GameMode.coop,
        ),
        const SizedBox(width: 4),
        seg(
          'SOLO',
          m.lastMode == GameMode.solo,
          () => m.lastMode = GameMode.solo,
        ),
        const SizedBox(width: 12),
        for (final d in Difficulty.values) ...[
          if (d.index > 0) const SizedBox(width: 4),
          seg(
            d.label.toUpperCase(),
            m.nextDifficulty == d,
            () => m.lastDifficulty = d.index,
            locked: d.index > m.maxDifficulty,
          ),
        ],
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({this.size = 64});
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: 'Voided. A seaside tower defence.',
    excludeSemantics: true,
    child: Column(
      children: [
        Transform.rotate(
          angle: -0.035,
          child: Text(
            'VOIDED',
            style:
                display(
                  size,
                  color: Vx.gold,
                  stroke: const Color(0xFF3A1A00),
                  w: 5,
                  spacing: 3,
                ).copyWith(
                  height: 1,
                  shadows: const [
                    Shadow(
                      color: Color(0xAA000000),
                      offset: Offset(0, 6),
                      blurRadius: 6,
                    ),
                  ],
                ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: Vx.ink.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Hold the pier till the season ends',
            style: body(
              12.5,
              color: const Color(0xFFFFE9A8),
              weight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SoundBtn extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const _SoundBtn({required this.meta, required this.save});
  @override
  State<_SoundBtn> createState() => _SoundBtnState();
}

class _SoundBtnState extends State<_SoundBtn> {
  @override
  Widget build(BuildContext context) {
    final on = Sfx.sound;
    return Tooltip(
      message: on ? 'Sound on' : 'Sound off',
      child: Chunky(
        tone: on ? Tone.blue : Tone.grey,
        width: 44,
        height: 44,
        radius: 14,
        padding: EdgeInsets.zero,
        semantics: 'Sound: ${on ? 'on' : 'off'}',
        onTap: () => setState(() {
          Sfx.sound = !Sfx.sound;
          widget.meta.sound = Sfx.sound;
          widget.save();
        }),
        child: Icon(
          on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

// ============================== LEVELS ==============================

/// Pick any level you have reached, who you're on shift with and the sea
/// state. PLAY on the home screen skips this and goes straight in.
class ModeSelect extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const ModeSelect({super.key, required this.meta, required this.save});
  @override
  State<ModeSelect> createState() => _ModeSelectState();
}

class _ModeSelectState extends State<ModeSelect> {
  MetaSave get m => widget.meta;
  late int lvl = m.levelReached;

  Widget _choice({
    required String title,
    required String sub,
    required bool on,
    required VoidCallback? onTap,
    Widget? leading,
    bool locked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: on,
        enabled: !locked,
        label: '$title. $sub${locked ? ' Locked.' : ''}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: locked || onTap == null
              ? null
              : () {
                  Sfx.click();
                  setState(onTap);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: on
                    ? [const Color(0xFF3F8EE8), const Color(0xFF2558B8)]
                    : [Vx.well, Vx.wellDeep],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: on ? Vx.gold : Vx.ink,
                width: on ? 3 : 2.5,
              ),
              boxShadow: const [BoxShadow(color: Vx.ink, offset: Offset(0, 3))],
            ),
            child: Opacity(
              opacity: locked ? 0.5 : 1,
              child: Row(
                children: [
                  if (leading != null) ...[leading, const SizedBox(width: 10)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: display(18, w: 1.6)),
                        Text(
                          sub,
                          style: body(
                            12,
                            color: on ? Colors.white : Vx.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    const Icon(Icons.lock_rounded, color: Colors.white70)
                  else if (on)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Vx.gold,
                      size: 26,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = math.min(
      m.levelReached + 1,
      math.max(kLevels.length, m.levelReached + 1),
    );
    return _Page(
      title: 'Pick your shift',
      meta: m,
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chunky.label(
              'OPEN UP',
              sub: 'Level $lvl · ${levelDef(lvl).name}',
              tone: Tone.green,
              height: 64,
              size: 26,
              onTap: () async {
                widget.save();
                await _startRun(context, m, widget.save, level: lvl);
                if (mounted) setState(() => lvl = lvl.clamp(1, m.levelReached));
              },
            ),
            TextButton(
              onPressed: () => _startRun(
                context,
                m,
                widget.save,
                level: lvl,
                tutorial: true,
              ),
              child: Text(
                'Replay the tutorial',
                style: body(13, color: Vx.textDim),
              ),
            ),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        children: [
          const _Label('Where'),
          for (var l = 1; l <= shown; l++)
            _choice(
              title: 'Level $l · ${levelDef(l).name}',
              sub: l < m.levelReached
                  ? 'Cleared · final boss ${kBossById[levelDef(l).finalBoss]!.name}'
                  : l == m.levelReached
                  ? (m.bestOnLevel(l) > 0
                        ? 'Best wave ${m.bestOnLevel(l)}/$kFinalWave'
                        : levelDef(l).blurb)
                  : 'Clear level ${l - 1} to open this stretch of coast',
              on: lvl == l,
              locked: l > m.levelReached,
              leading: SpriteImg(
                'b_${levelDef(l).finalBoss}',
                size: 46,
                dim: l > m.levelReached,
              ),
              onTap: () => lvl = l,
            ),
          const _Label('Who\'s on shift'),
          _choice(
            title: 'Co-op with $kPartnerName',
            sub:
                '$kPartnerName runs the other half of the pier. You can pass her figurines.',
            on: m.lastMode == GameMode.coop,
            leading: const SpriteImg('i_cup', size: 40),
            onTap: () => m.lastMode = GameMode.coop,
          ),
          _choice(
            title: 'Solo',
            sub: 'Just you and the whole sea. Brutal, but it pays the same.',
            on: m.lastMode == GameMode.solo,
            leading: const SpriteImg('i_penny', size: 40),
            onTap: () => m.lastMode = GameMode.solo,
          ),
          const _Label('Sea state'),
          for (final d in Difficulty.values)
            _choice(
              title: d.label,
              sub: d.index <= m.maxDifficulty
                  ? d.blurb
                  : 'Clear a level on ${Difficulty.values[d.index - 1].label} to unlock.',
              on: m.nextDifficulty == d,
              locked: d.index > m.maxDifficulty,
              onTap: () => m.lastDifficulty = d.index,
            ),
        ],
      ),
    );
  }
}

// ============================== BACK ROOM ==============================

class BackRoom extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const BackRoom({super.key, required this.meta, required this.save});
  @override
  State<BackRoom> createState() => _BackRoomState();
}

class _BackRoomState extends State<BackRoom> {
  static const _sprites = {
    'float': 'i_penny',
    'clover': 'i_leaf',
    'bentcoin': 'i_dice',
    'grease': 'i_upgrade',
  };

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return _Page(
      title: 'The Back Room',
      meta: m,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          Well(
            child: Row(
              children: [
                const SpriteImg('i_glass', size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Madge keeps the good stuff behind the counter. Sea glass buys things that last from one season to the next.',
                    style: body(12.5, color: Vx.textDim, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const _Label('On the shelf'),
          for (final u in kMetaUpgrades) _shelfItem(m, u),
        ],
      ),
    );
  }

  Widget _shelfItem(MetaSave m, MetaUpgrade u) {
    final lvl = m.level(u.id);
    final maxed = (m.level(u.id) >= u.max);
    final cost = maxed ? 0 : u.cost(m.level(u.id));
    final can = !maxed && m.seaGlass >= cost;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GamePanel(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Well(
              padding: const EdgeInsets.all(4),
              child: SpriteImg(_sprites[u.id] ?? 'i_cup', size: 50),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name, style: display(17, w: 1.5)),
                  const SizedBox(height: 2),
                  Text(
                    u.desc,
                    style: body(11.5, color: Vx.textDim, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    label: 'Level $lvl of ${u.max}',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        for (var i = 0; i < u.max; i++)
                          Container(
                            width: 16,
                            height: 10,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: i < lvl ? Vx.gold : Vx.wellDeep,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Vx.ink, width: 1.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chunky(
              tone: maxed ? Tone.grey : Tone.green,
              width: 84,
              height: 54,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              enabled: can,
              semantics: maxed
                  ? '${u.name}, sold out'
                  : 'Buy ${u.name} for $cost sea glass${can ? '' : ', not enough glass'}',
              onTap: maxed
                  ? null
                  : () {
                      if (m.buy(u)) {
                        Sfx.upgrade();
                        widget.save();
                        setState(() {});
                      } else {
                        Sfx.error();
                      }
                    },
              child: maxed
                  ? Text(
                      'SOLD\nOUT',
                      textAlign: TextAlign.center,
                      style: display(13, stroke: Tone.grey.lip, w: 1.2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SpriteImg('i_glass', size: 20),
                        const SizedBox(width: 3),
                        Text(
                          '$cost',
                          style: display(18, stroke: Tone.green.lip, w: 1.6),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== JOBS ==============================

class JobsBoard extends StatelessWidget {
  final MetaSave meta;
  const JobsBoard({super.key, required this.meta});

  @override
  Widget build(BuildContext context) {
    final done = kMissions.where((x) => meta.missions.contains(x.id)).length;
    final todo = [
      ...kMissions.where((x) => !meta.missions.contains(x.id)),
      ...kMissions.where((x) => meta.missions.contains(x.id)),
    ];
    return _Page(
      title: 'Jobs Board',
      meta: meta,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          GamePanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Odd jobs pinned up by the management. Each pays sea glass once.',
                  style: body(12.5, color: Vx.textDim),
                ),
                const SizedBox(height: 8),
                ProgressPill(
                  value: kMissions.isEmpty ? 0 : done / kMissions.length,
                  label: '$done / ${kMissions.length} DONE',
                  color: Tone.green.top,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final x in todo)
            _Ticket(job: x, done: meta.missions.contains(x.id)),
        ],
      ),
    );
  }
}

/// A job as a torn-off arcade prize ticket: reward on the stub, the job on
/// the body, and a big stamp once it's done.
class _Ticket extends StatelessWidget {
  final Mission job;
  final bool done;
  const _Ticket({required this.job, required this.done});

  @override
  Widget build(BuildContext context) {
    final paper = done ? const Color(0xFFBFE7B0) : const Color(0xFFFFE3A3);
    final stub = done ? const Color(0xFF5DBB4C) : const Color(0xFFFF9F43);
    return Semantics(
      container: true,
      label:
          '${job.name}. ${job.desc} ${done ? 'Done.' : 'Pays ${job.reward} sea glass.'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Vx.ink, width: 2.5),
            boxShadow: const [BoxShadow(color: Vx.ink, offset: Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 70,
                    color: stub,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SpriteImg('i_glass', size: 26),
                        Text('+${job.reward}', style: display(18, w: 1.8)),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: const Size(8, 0),
                    painter: _Perforation(stub, paper),
                  ),
                  Expanded(
                    child: Container(
                      color: paper,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                job.name.toUpperCase(),
                                style: display(
                                  15,
                                  color: const Color(0xFF3A1F0B),
                                  stroke: paper,
                                  w: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                job.desc,
                                style: body(
                                  12,
                                  color: const Color(0xFF5A3A1E),
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (done)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Transform.rotate(
                                  angle: -0.25,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xCC2E7D32),
                                        width: 2.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'DONE',
                                      style: display(
                                        16,
                                        color: const Color(0xCC2E7D32),
                                        stroke: paper,
                                        w: 0,
                                        spacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
}

class _Perforation extends CustomPainter {
  final Color left, right;
  const _Perforation(this.left, this.right);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width / 2, size.height),
      Paint()..color = left,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
      Paint()..color = right,
    );
    final hole = Paint()..color = Vx.ink;
    for (var y = 5.0; y < size.height; y += 9) {
      canvas.drawCircle(Offset(size.width / 2, y), 2.2, hole);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) =>
      old.left != left || old.right != right;
}

// ============================== ALBUM ==============================

class Album extends StatelessWidget {
  final MetaSave meta;
  const Album({super.key, required this.meta});

  @override
  Widget build(BuildContext context) {
    final pages = kUnits.where(meta.collected).length;
    return _Page(
      title: 'Figurine Album',
      meta: meta,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            sliver: SliverToBoxAdapter(
              child: GamePanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Every figurine you place goes in the album. Fill a page and the arcade pays out sea glass.',
                      style: body(12.5, color: Vx.textDim),
                    ),
                    const SizedBox(height: 8),
                    ProgressPill(
                      value: pages / kUnits.length,
                      label: '$pages / ${kUnits.length} PAGES FILLED',
                      color: Tone.purple.top,
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final t in Tier.values) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    _Tag(t.label, toneForTier(t.index)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Page needs ${albumNeed(t)} · pays ${albumReward(t)}',
                        style: body(11.5, color: Vx.textDim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 112,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildListDelegate([
                  for (final d in kUnits.where((u) => u.tier == t))
                    _AlbumCard(meta: meta, d: d),
                ]),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final MetaSave meta;
  final UnitDef d;
  const _AlbumCard({required this.meta, required this.d});

  @override
  Widget build(BuildContext context) {
    final seen = meta.discovered.contains(d.id);
    final have = meta.copies[d.id] ?? 0;
    final need = albumNeed(d.tier);
    final full = meta.collected(d);
    final tone = toneForTier(d.tier.index);
    return Semantics(
      button: seen,
      label: seen
          ? '${d.name}, ${d.tier.label}. ${full ? 'Page filled.' : '$have of $need.'}'
          : 'Unknown ${d.tier.label} figurine.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: seen ? () => _details(context) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: seen ? [tone.top, tone.bottom] : [Vx.well, Vx.wellDeep],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: full ? Vx.gold : Vx.ink,
              width: full ? 3 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: seen ? tone.lip : Vx.ink,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    UnitIcon(d, size: 56, locked: !seen),
                    if (full)
                      const Positioned(
                        top: 2,
                        right: 6,
                        child: Icon(
                          Icons.star_rounded,
                          color: Vx.gold,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                seen ? d.name : '???',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: display(12, stroke: seen ? tone.lip : Vx.ink, w: 1.2),
              ),
              const SizedBox(height: 3),
              Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Vx.ink, width: 1.2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (have / need).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Vx.gold,
                      borderRadius: BorderRadius.circular(3),
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

  void _details(BuildContext context) {
    final have = meta.copies[d.id] ?? 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              type: MaterialType.transparency,
              child: GameDialogFrame(
                title: d.name,
                tone: toneForTier(d.tier.index),
                onClose: () => Navigator.of(ctx).pop(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UnitIcon(d, size: 96),
                    const SizedBox(height: 6),
                    _Tag(d.tier.label, toneForTier(d.tier.index)),
                    const SizedBox(height: 8),
                    Text(d.desc, textAlign: TextAlign.center, style: body(13)),
                    const SizedBox(height: 6),
                    Text(
                      '"${d.quip}"',
                      textAlign: TextAlign.center,
                      style: body(
                        12,
                        color: Vx.textDim,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        StatTile('Damage', d.dmg.toStringAsFixed(0)),
                        StatTile('Hits/s', (1 / d.interval).toStringAsFixed(1)),
                        StatTile('Range', d.range.toStringAsFixed(1)),
                        StatTile('Placed', '$have/${albumNeed(d.tier)}'),
                      ],
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

// ============================== SEA THINGS ==============================

class Bestiary extends StatefulWidget {
  final MetaSave meta;
  const Bestiary({super.key, required this.meta});
  @override
  State<Bestiary> createState() => _BestiaryState();
}

class _BestiaryState extends State<Bestiary> {
  bool bosses = false;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool on, VoidCallback onTap) => Expanded(
      child: Chunky(
        tone: on ? Tone.teal : Tone.grey,
        height: 44,
        radius: 14,
        semantics: '$label${on ? ', selected' : ''}',
        onTap: () => setState(onTap),
        child: Text(
          label,
          style: display(16, stroke: (on ? Tone.teal : Tone.grey).lip, w: 1.5),
        ),
      ),
    );
    return _Page(
      title: 'Sea Things',
      meta: widget.meta,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              children: [
                tab('SEA THINGS', !bosses, () => bosses = false),
                const SizedBox(width: 8),
                tab('BOSSES', bosses, () => bosses = true),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              children: bosses
                  ? [for (final b in kBosses) _bossCard(b)]
                  : [for (final e in kEnemies) _enemyCard(e)],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _levelsFor(String enemyId) => [
    for (var l = 1; l <= kLevels.length; l++)
      if ([
        for (final w in [3, 12, 25, 40]) ...enemyPool(w, l),
      ].contains(enemyId))
        l,
  ];

  Widget _enemyCard(EnemyDef e) {
    final traits = <(String, Tone)>[
      if (e.speed >= 1.3) ('Fast', Tone.yellow),
      if (e.armor > 0) ('Armoured', Tone.grey),
      if (e.evade > 0) ('Dodgy', Tone.purple),
      if (e.healAura > 0) ('Heals', Tone.green),
      if (e.splitInto != null) ('Splits', Tone.red),
    ];
    final levels = _levelsFor(e.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Well(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFF2E7FB8), Color(0xFF123C66)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Vx.ink, width: 2),
              ),
              child: EnemyIcon(enemy: e, size: 52),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name, style: display(16, w: 1.5)),
                  Text(
                    e.blurb,
                    style: body(12, color: Vx.textDim, height: 1.25),
                  ),
                  if (traits.isNotEmpty || levels.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final (t, tone) in traits) _Tag(t, tone),
                        if (levels.isNotEmpty && levels.length < kLevels.length)
                          _Tag('Level ${levels.join(', ')}', Tone.blue),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bossCard(BossDef b) {
    final finalOf = [
      for (var l = 1; l <= kLevels.length; l++)
        if (levelDef(l).finalBoss == b.id) l,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A1630), Color(0xFF2A0F22)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: finalOf.isNotEmpty ? Vx.gold : Vx.ink,
            width: finalOf.isNotEmpty ? 3 : 2.5,
          ),
          boxShadow: const [BoxShadow(color: Vx.ink, offset: Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpriteImg('b_${b.id}', size: 82),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (finalOf.isNotEmpty)
                        _Tag(
                          'Final boss · Level ${finalOf.join(', ')}',
                          Tone.yellow,
                        )
                      else
                        _Tag('Turns up on the tens', Tone.red),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.name,
                    style: display(19, stroke: const Color(0xFF16060F), w: 1.8),
                  ),
                  Text(
                    b.title,
                    style: body(
                      12,
                      color: const Color(0xFFFFB3C1),
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.mechText,
                    style: body(12, color: Colors.white, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
