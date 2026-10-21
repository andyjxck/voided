// Front of house: title, mode select, the Back Room, the Jobs board, the album.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/data.dart';
import '../game/meta.dart';
import 'art.dart';
import 'game_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const HomeScreen({super.key, required this.meta, required this.save});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  MetaSave get meta => widget.meta;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _go(Widget w) async {
    Sfx.unlock();
    Sfx.click();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {});
  }

  void _play() {
    Sfx.unlock();
    if (Sfx.music) Sfx.setMusic(true);
    _go(ModeSelect(meta: meta, save: widget.save));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: _anim, builder: (_, _) => CustomPaint(painter: _TitleBg(_anim.value)))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 10),
                const Text('PIER', style: TextStyle(color: Pal.neon, fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 10, height: 0.9)),
                const Text('PRESSURE',
                    style: TextStyle(color: Pal.danger, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 8, height: 1.0)),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 340,
                  child: Text(
                    'Last night of the season on Grimley Pier. Something is climbing out of the sea. The fortune machine is your only hope, and it is rigged.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final id in ['gull', 'thwack', 'morag', 'vex', 'velvet']) UnitIcon(kUnitById[id]!, size: 52),
                ]),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.diamond_outlined, color: Color(0xFF7FDBFF), size: 18),
                  const SizedBox(width: 6),
                  Text('${meta.seaGlass} sea glass', style: const TextStyle(color: Color(0xFF7FDBFF), fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 12),
                MenuButton(label: 'PLAY', primary: true, sub: meta.tutorialDone ? null : 'First time? The tutorial runs on your first go', onTap: _play),
                MenuButton(label: 'The Back Room', sub: 'Permanent upgrades', onTap: () => _go(BackRoom(meta: meta, save: widget.save))),
                MenuButton(
                    label: 'Jobs Board',
                    sub: '${meta.missions.length}/${kMissions.length} done',
                    onTap: () => _go(JobsBoard(meta: meta))),
                MenuButton(
                    label: 'Figurine Album',
                    sub: '${meta.discovered.length}/${kUnits.length} found',
                    onTap: () => _go(Album(meta: meta))),
                MenuButton(label: 'Sea Things & Bosses', onTap: () => _go(const Bestiary())),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, runSpacing: 6, children: [
                  _toggle('Sound', meta.sound, (v) {
                    meta.sound = v;
                    Sfx.sound = v;
                  }),
                  _toggle('Music', meta.music, (v) {
                    meta.music = v;
                    Sfx.unlock();
                    Sfx.setMusic(v);
                  }),
                  _toggle('Shake', meta.shake, (v) => meta.shake = v),
                ]),
                const SizedBox(height: 6),
                Text('Runs ${meta.runs} · Wins ${meta.wins}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _toggle(String label, bool v, void Function(bool) set) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilterChip(
          selected: v,
          label: Text(label),
          onSelected: (x) => setState(() {
            set(x);
            widget.save();
          }),
        ),
      );
}

class _TitleBg extends CustomPainter {
  final double k;
  _TitleBg(this.k);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF050A1A), Color(0xFF14254A)])
              .createShader(Offset.zero & s));
    // moon
    c.drawCircle(Offset(s.width * 0.82, s.height * 0.12), 34, Paint()..color = const Color(0xFFFFF4DC));
    c.drawCircle(Offset(s.width * 0.82 + 12, s.height * 0.12 - 6), 30, Paint()..color = const Color(0xFF060C1D));
    // sea
    final t = k * math.pi * 2;
    for (var i = 0; i < 14; i++) {
      final y = s.height * 0.55 + i * 26.0;
      final p = Path();
      for (var x = 0.0; x <= s.width; x += 10) {
        final yy = y + math.sin(x / 50 + t + i) * 4;
        x == 0 ? p.moveTo(x, yy) : p.lineTo(x, yy);
      }
      c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.04 + i * 0.004));
    }
    // pier silhouette with lights
    final deckY = s.height * 0.6;
    c.drawRect(Rect.fromLTWH(0, deckY, s.width, 10), Paint()..color = const Color(0xFF1A120C));
    for (var x = 10.0; x < s.width; x += 46) {
      c.drawRect(Rect.fromLTWH(x, deckY + 10, 6, s.height), Paint()..color = const Color(0xFF110B08));
    }
    for (var i = 0; i * 22.0 < s.width; i++) {
      final on = ((i + (k * 18).floor()) % 3) != 0;
      final col = [Pal.neon, Pal.danger, const Color(0xFF7FDBFF)][i % 3];
      final x = i * 22.0 + 6;
      final y = deckY - 16 + math.sin(i * 0.6) * 4;
      c.drawCircle(Offset(x, y), on ? 3.5 : 2.5, Paint()..color = on ? col : col.withValues(alpha: 0.2));
      if (on) c.drawCircle(Offset(x, y), 9, Paint()..color = col.withValues(alpha: 0.12));
    }
    // eyes in the water
    for (var i = 0; i < 5; i++) {
      final x = s.width * (0.1 + i * 0.2) + math.sin(t + i) * 10;
      final y = s.height * 0.75 + (i % 2) * 60.0;
      final blink = ((k * 7 + i * 0.37) % 1.0) < 0.05;
      if (blink) continue;
      for (final dx in [-6.0, 6.0]) {
        c.drawCircle(Offset(x + dx, y), 3, Paint()..color = const Color(0xFFFFE066).withValues(alpha: 0.75));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TitleBg old) => old.k != k;
}

class _Page extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Page({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Pal.sea,
        appBar: AppBar(
          backgroundColor: Pal.panel,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          actions: [if (trailing != null) Padding(padding: const EdgeInsets.only(right: 12), child: trailing)],
        ),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child)),
      );
}

class ModeSelect extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const ModeSelect({super.key, required this.meta, required this.save});
  @override
  State<ModeSelect> createState() => _ModeSelectState();
}

class _ModeSelectState extends State<ModeSelect> {
  GameMode mode = GameMode.coop;
  Difficulty diff = Difficulty.calm;

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return _Page(
      title: 'Open the pier',
      // The list scrolls; OPEN UP stays pinned so it is never below the fold.
      child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), children: [
        const Text('WHO\'S ON SHIFT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _choice(
          selected: mode == GameMode.coop,
          title: 'Co-op with $kPartnerName',
          body: '$kPartnerName (AI) runs the top board, you run the bottom. The boardwalk loops round both, and you both hit whatever walks the middle. She chats, she slips you a free summon after every boss, and you can hand her figurines.',
          onTap: () => setState(() => mode = GameMode.coop),
        ),
        _choice(
          selected: mode == GameMode.solo,
          title: 'Solo',
          body: 'Just you and the machine on a smaller pier. Sea things have ${(kSoloHpMultiplier * 100).round()}% of their co-op health to make it fair.',
          onTap: () => setState(() => mode = GameMode.solo),
        ),
        const SizedBox(height: 14),
        const Text('FORECAST', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        for (final d in Difficulty.values)
          _choice(
            selected: diff == d,
            locked: d.index > m.maxDifficulty,
            title: d.label + (m.best['${mode.name}-${d.name}'] != null ? '   · best wave ${m.best['${mode.name}-${d.name}']}' : ''),
            body: d.index > m.maxDifficulty ? 'Win on ${Difficulty.values[d.index - 1].label} to unlock.' : d.blurb,
            onTap: d.index > m.maxDifficulty ? null : () => setState(() => diff = d),
          ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: MenuButton(
            label: 'OPEN UP',
            primary: true,
            onTap: () {
              Sfx.unlock();
              Sfx.click();
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => GameScreen(meta: m, mode: mode, difficulty: diff, onSave: widget.save, tutorial: !m.tutorialDone),
              ));
            },
          ),
        ),
        if (m.tutorialDone)
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => GameScreen(meta: m, mode: mode, difficulty: diff, onSave: widget.save, tutorial: true),
              )),
              child: const Text('Play with the tutorial again', style: TextStyle(color: Colors.white54)),
            ),
          ),
            ]),
          ),
        ]),
    );
  }

  Widget _choice({required bool selected, required String title, required String body, VoidCallback? onTap, bool locked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFF3A2F5E) : Pal.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? Pal.neon : Colors.transparent, width: 2)),
            child: Row(children: [
              Icon(locked ? Icons.lock : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
                  color: locked ? Colors.white30 : Pal.neon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: locked ? Colors.white38 : Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class BackRoom extends StatefulWidget {
  final MetaSave meta;
  final VoidCallback save;
  const BackRoom({super.key, required this.meta, required this.save});
  @override
  State<BackRoom> createState() => _BackRoomState();
}

class _BackRoomState extends State<BackRoom> {
  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return _Page(
      title: 'The Back Room',
      trailing: Text('${m.seaGlass} sea glass', style: const TextStyle(color: Color(0xFF7FDBFF), fontWeight: FontWeight.w900)),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Sea glass washes up after every run. The arcade manager will swap it for "improvements". Don\'t ask where they came from.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
        const SizedBox(height: 12),
        for (final u in kMetaUpgrades)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WideBtn(
              title: '${u.name}   ${'●' * m.level(u.id)}${'○' * (u.max - m.level(u.id))}',
              sub: m.level(u.id) >= u.max ? '${u.desc} · maxed' : '${u.desc} · ${u.cost(m.level(u.id))} sea glass',
              color: const Color(0xFF7FDBFF),
              enabled: m.level(u.id) < u.max && m.seaGlass >= u.cost(m.level(u.id)),
              onTap: () => setState(() {
                if (m.buy(u)) {
                  Sfx.upgrade();
                  widget.save();
                }
              }),
            ),
          ),
      ]),
    );
  }
}

class JobsBoard extends StatelessWidget {
  final MetaSave meta;
  const JobsBoard({super.key, required this.meta});
  @override
  Widget build(BuildContext context) => _Page(
        title: 'Jobs Board',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final m in kMissions)
            Card(
              color: meta.missions.contains(m.id) ? const Color(0xFF1F3A26) : Pal.panel,
              child: ListTile(
                leading: Icon(meta.missions.contains(m.id) ? Icons.check_circle : Icons.push_pin,
                    color: meta.missions.contains(m.id) ? Pal.leaf : Pal.danger),
                title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(m.desc),
                trailing: Text('+${m.reward}', style: const TextStyle(color: Color(0xFF7FDBFF), fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      );
}

class Album extends StatelessWidget {
  final MetaSave meta;
  const Album({super.key, required this.meta});
  @override
  Widget build(BuildContext context) {
    final odds = summonOdds(0);
    return _Page(
      title: 'Figurine Album',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Machine odds: ${Tier.values.take(4).map((t) => '${t.label} ${odds[t.index].toStringAsFixed(0)}%').join(' · ')}. '
            'Mythics only come from recipes. Seven Commons in a row and the machine takes pity.',
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
        const SizedBox(height: 10),
        for (final t in Tier.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(t.label.toUpperCase(), style: TextStyle(color: Color(t.color), fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
          for (final u in unitsOfTier(t)) _unitRow(u, meta.discovered.contains(u.id)),
        ],
      ]),
    );
  }

  Widget _unitRow(UnitDef u, bool found) {
    final recipe = kRecipes[u.id];
    return Card(
      color: Pal.panel,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          UnitIcon(u, size: 54, locked: !found && recipe == null),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(found || recipe != null ? u.name : '???', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              Text('${u.tags.join(', ')} · ${u.dps.toStringAsFixed(0)} dps · range ${u.range}',
                  style: TextStyle(color: Color(u.tier.color), fontSize: 12, fontWeight: FontWeight.w700)),
              Text(found || recipe != null ? u.desc : 'Not found yet. Keep feeding the machine.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (found) Text('"${u.quip}"', style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
              if (recipe != null)
                Text('Recipe: ${recipe.map((id) => kUnitById[id]!.name).join(' + ')}', style: const TextStyle(color: Pal.danger, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class Bestiary extends StatelessWidget {
  const Bestiary({super.key});
  @override
  Widget build(BuildContext context) => _Page(
        title: 'Sea Things & Bosses',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final e in kEnemies)
            Card(
              color: Pal.panel,
              child: ListTile(
                leading: EnemyIcon(enemy: e, size: 46),
                title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(e.blurb),
              ),
            ),
          const SizedBox(height: 12),
          const Text('BOSSES', style: TextStyle(color: Pal.danger, fontWeight: FontWeight.w900, letterSpacing: 2)),
          for (final b in kBosses)
            Card(
              color: const Color(0xFF2A0F22),
              child: ListTile(
                leading: EnemyIcon(boss: b, size: 52),
                title: Text('Wave ${(kBosses.indexOf(b) + 1) * 10}: ${b.name}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${b.title}. ${b.mechText}\n"${b.entrance}"'),
                isThreeLine: true,
              ),
            ),
        ]),
      );
}
