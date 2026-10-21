// Pier Pressure — the simulation. Pure Dart, deterministic for a seed, no
// Flutter imports, so tests and balance sims can run thousands of waves fast.

import 'dart:math' as math;

import 'data.dart';

/// Seconds between sea things leaving the gate. A pair counts as two.
const double kSpawnGap = 0.75;

/// Share of the boss's health each twin gets on Calm, by mode.
///
/// Co-op: each board fights its own twin, so each twin is close to a whole
/// boss. Solo: your one board meets both, one coming each way round. Two
/// targets half a lap apart keep far more figurines in range than one does,
/// so each twin still needs well over half a boss's health.
///
/// Splitting a boss also blunts the difficulty's health multiplier (two
/// targets soak it less than one), so on Choppy and Storm the share grows
/// with the square root of that multiplier; see [twinBossHpShare]. The
/// numbers were set by simulated runs against the single-boss version
/// (tool/twin_probe.dart) to keep the same win rates on Calm and the same
/// step up to Choppy and Storm.
const Map<GameMode, double> kTwinBossHpShare = {
  GameMode.coop: 0.9,
  GameMode.solo: 0.55,
};

/// What each twin gets of a boss's health in [mode] on [d].
double twinBossHpShare(GameMode mode, Difficulty d) =>
    kTwinBossHpShare[mode]! * math.sqrt(d.hpMult);

class V2 {
  final double x, y;
  const V2(this.x, this.y);
  double dist(V2 o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
}

/// Field geometry, in cell units.
///
/// Everything comes out of one gate in the middle of the boardwalk and splits:
/// one sea thing turns left, its twin turns right. Each turning is its own
/// closed loop (a "route"), and both loops have the same length.
///
/// Co-op: the gate is the exact centre of the map, on the shared middle
/// boardwalk between the two boards. Left goes round your board (bottom),
/// right goes round Brenda's (top). Each board has its own loop and every pair
/// sends one sea thing to each board; the middle boardwalk is a two-lane road
/// the two loops share, so figurines on the inner rows reach both.
///
/// Solo: there is one board, so the gate sits at the middle of the boardwalk
/// above it. Left goes round the board anticlockwise, right goes round it
/// clockwise, each on its own side of the boardwalk so they pass, not stack.
///
/// An enemy's route lives in its [Enemy.s]: route r runs from
/// `routeBase(r)`, which is a whole number of laps, so `s % lap` is still the
/// distance round the loop and code that compares two `s` values only ever
/// treats enemies on the same route as close.
class Field {
  final GameMode mode;
  late final double w;
  late final double h;
  late final double lap;

  /// Where the gate is: the middle of the map in co-op.
  late final V2 gate;

  /// One closed loop per route. Route 0 turns left out of the gate, route 1
  /// turns right.
  late final List<List<V2>> routes;
  late final List<List<double>> _cums;

  /// The boardwalk to draw: closed loops through the middle of the planks.
  /// Enemies walk in lanes either side of these.
  late final List<List<V2>> walks;

  /// How far apart the two lanes are where loops share or retrace boardwalk.
  static const double laneGap = 0.34;

  Field(this.mode) {
    w = kBoardCols + 2.0;
    final a = w - 0.5;
    final cx = w / 2;
    if (mode == GameMode.solo) {
      h = kBoardRows + 2.0;
      gate = V2(cx, 0.5);
      // Anticlockwise rides the inside lane of the boardwalk, clockwise the
      // outside, so the two only ever pass side by side. The outside lane is a
      // little longer; posAt stretches each loop to one shared lap, so in
      // solo the clockwise walker covers ground about 6% faster and the
      // anticlockwise one about 6% slower. Both lap in the same time.
      const d = laneGap / 2;
      final ring = [
        const V2(0.5, 0.5),
        V2(0.5, h - 0.5),
        V2(a, h - 0.5),
        V2(a, 0.5),
      ];
      walks = [ring];
      List<V2> inset(List<V2> pts, double by) => [
        for (final p in pts)
          V2(
            p.x < cx ? p.x + by : (p.x > cx ? p.x - by : p.x),
            p.y < h / 2 ? p.y + by : p.y - by,
          ),
      ];
      final left = [V2(cx, 0.5), ...ring];
      final right = [V2(cx, 0.5), ...ring.skip(1).toList().reversed, ring[0]];
      routes = [inset(left, d), inset(right, -d)];
    } else {
      h = kBoardRows * 2 + 3.0;
      final mid = kBoardRows + 1.5;
      gate = V2(cx, mid);
      const d = laneGap / 2;
      // Left: round your board (bottom), on the lower lane of the middle.
      final left = [
        V2(cx, mid + d),
        V2(0.5, mid + d),
        V2(0.5, h - 0.5),
        V2(a, h - 0.5),
        V2(a, mid + d),
      ];
      // Right: round Brenda's board (top), on the upper lane of the middle.
      final right = [
        V2(cx, mid - d),
        V2(a, mid - d),
        V2(a, 0.5),
        const V2(0.5, 0.5),
        V2(0.5, mid - d),
      ];
      // Both loops are the same length: each vertical run is shortened by d.
      routes = [left, right];
      walks = [
        [V2(0.5, mid), V2(0.5, h - 0.5), V2(a, h - 0.5), V2(a, mid)],
        [V2(a, mid), V2(a, 0.5), const V2(0.5, 0.5), V2(0.5, mid)],
      ];
    }
    _cums = [
      for (final pts in routes)
        () {
          final c = <double>[0];
          for (var i = 0; i < pts.length; i++) {
            c.add(c.last + pts[i].dist(pts[(i + 1) % pts.length]));
          }
          return c;
        }(),
    ];
    // The shared lap: the average loop. Co-op loops are exactly equal.
    lap = _cums.map((c) => c.last).reduce((x, y) => x + y) / _cums.length;
  }

  int get routeCount => routes.length;

  /// The loop for route 0, kept for code that wants one outline.
  List<V2> get pts => routes.first;

  /// Start of route [r] in [Enemy.s] terms. A whole number of laps apart, so
  /// `s % lap` ignores it.
  double routeBase(int r) => r * lap * _band;
  static const int _band = 1000;

  /// Which route an [Enemy.s] is on. Bands are centred on their base, so a
  /// child spawned a little behind the gate stays on its parent's route.
  int routeOf(double s) {
    final r = ((s + lap * _band / 2) / (lap * _band)).floor();
    return r.clamp(0, routes.length - 1);
  }

  /// Index of the board a route goes round (co-op), or 0 in solo.
  int boardOfRoute(int r) => mode == GameMode.solo ? 0 : (r == 0 ? 0 : 1);

  V2 posAt(double s) {
    final r = routeOf(s);
    final pts = routes[r];
    final cum = _cums[r];
    var t = (s - routeBase(r)) % lap;
    if (t < 0) t += lap;
    // Every route is walked in one shared lap; a longer loop is stretched.
    t *= cum.last / lap;
    var i = 0;
    while (i < pts.length - 1 && cum[i + 1] <= t) {
      i++;
    }
    final p0 = pts[i], p1 = pts[(i + 1) % pts.length];
    final segLen = cum[i + 1] - cum[i];
    final f = segLen <= 0 ? 0.0 : (t - cum[i]) / segLen;
    return V2(p0.x + (p1.x - p0.x) * f, p0.y + (p1.y - p0.y) * f);
  }

  /// Board top-left for side [i]. Side 0 is always the human player (bottom).
  V2 boardOrigin(int i) {
    if (mode == GameMode.solo) return const V2(1, 1);
    return i == 0 ? V2(1, kBoardRows + 2.0) : const V2(1, 1);
  }

  V2 cellCenter(int side, int cell) {
    final o = boardOrigin(side);
    return V2(o.x + cell % kBoardCols + 0.5, o.y + cell ~/ kBoardCols + 0.5);
  }

  /// Fraction of all the boardwalk within [r] of a cell: how good a spot it is.
  double coverage(int side, int cell, [double r = 2.8]) {
    const n = 200;
    var hit = 0;
    final c = cellCenter(side, cell);
    for (var k = 0; k < routes.length; k++) {
      for (var i = 0; i < n; i++) {
        if (posAt(routeBase(k) + lap * i / n).dist(c) <= r) hit++;
      }
    }
    return hit / (n * routes.length);
  }

  late final List<List<int>> placeOrder = [
    for (var side = 0; side < (mode == GameMode.solo ? 1 : 2); side++)
      (List.generate(kBoardCols * kBoardRows, (i) => i)
        ..sort((x, y) => coverage(side, y).compareTo(coverage(side, x)))),
  ];
}

class UnitInst {
  final UnitDef def;
  final int uid;
  double cd;
  int attacks = 0;
  double special = 0;
  double born;
  UnitInst(this.def, this.uid, this.born) : cd = 0.3;
}

class Cell {
  final List<UnitInst> units = [];
  double disabled = 0;
  bool get isEmpty => units.isEmpty;
  UnitDef? get def => units.isEmpty ? null : units.first.def;
  bool canTake(UnitDef d) =>
      units.isEmpty || (units.first.def.id == d.id && units.length < kStackMax);
}

class SideStats {
  int summons = 0,
      merges = 0,
      sold = 0,
      rerolls = 0,
      gambles = 0,
      gambleWins = 0;
  int mythics = 0, kills = 0, upgrades = 0;
  int pennyEarned = 0;
}

class PlayerSide {
  final int index;
  final List<Cell> cells = List.generate(
    kBoardCols * kBoardRows,
    (_) => Cell(),
  );
  int pennies;
  int leaves;
  int summons = 0;
  int luck = 0;
  final List<int> upg = [0, 0, 0];
  int arcadeKills = 0;
  int dryStreak = 0;
  final SideStats stats = SideStats();

  /// Every figurine id this side has had on its board (for the album).
  final Set<String> seen = {};

  /// How many of each figurine this side has had on its board this run.
  final Map<String, int> got = {};
  PlayerSide(this.index, this.pennies, this.leaves);

  int get unitCount => cells.fold(0, (a, c) => a + c.units.length);
  bool get hasEmptyCell => cells.any((c) => c.isEmpty);
  Iterable<UnitInst> get allUnits sync* {
    for (final c in cells) {
      yield* c.units;
    }
  }

  int countOf(String id) => allUnits.where((u) => u.def.id == id).length;

  /// Union rules switched on: 3+ distinct figurines sharing the tag.
  Set<String> activeUnions() {
    final byTag = <String, Set<String>>{};
    for (final u in allUnits) {
      for (final t in u.def.tags) {
        (byTag[t] ??= <String>{}).add(u.def.id);
      }
    }
    return {
      for (final e in byTag.entries)
        if (e.value.length >= 3) e.key,
    };
  }
}

class Enemy {
  final int id;
  final EnemyDef? def;
  final BossDef? boss;
  double hp;
  double maxHp;
  double s;
  double traveled = 0;
  double speed;
  double armor;
  double evade;
  double slowPct = 0, slowT = 0, stunT = 0, freezeT = 0;
  double cursePct = 0, curseT = 0;
  double burnDps = 0, burnT = 0;
  double shield = 0;
  double mechT = 0;
  double diveT = 0;
  double surgeT = 0;
  int laps = 0;
  int phase = 0;
  double hitFlash = 0;
  bool dead = false;
  Enemy(
    this.id,
    this.def,
    this.boss,
    this.maxHp,
    this.s,
    this.speed,
    this.armor,
    this.evade,
  ) : hp = maxHp;
  bool get isBoss => boss != null;
  bool get submerged => diveT > 0;
  String get name => boss?.name ?? def!.name;
}

enum FxType {
  shot,
  hit,
  kill,
  summon,
  merge,
  mythic,
  boss,
  shake,
  text,
  jackpot,
  freeze,
  condemn,
  miss,
  gamble,
  sell,
  beam,
  pulse,
}

class Fx {
  final FxType type;
  final double x, y, x2, y2;
  final int color;
  final String text;
  final double size;
  Fx(
    this.type, {
    this.x = 0,
    this.y = 0,
    this.x2 = 0,
    this.y2 = 0,
    this.color = 0xFFFFFFFF,
    this.text = '',
    this.size = 1,
  });
}

class ChatLine {
  final String speaker;
  final String text;
  final double at;
  ChatLine(this.speaker, this.text, this.at);
}

enum GameStatus { playing, won, lost }

class GameConfig {
  final GameMode mode;
  final Difficulty difficulty;
  final int seed;
  final int bonusPennies;
  final int bonusLeaves;
  final int summonDiscount;
  final double dmgBonus;
  final double hpScaleOverride; // tests / sims only; 0 = use mode default

  /// Which level this run is, from 1. Sets the enemies, the bosses and how
  /// tough everything is.
  final int level;
  const GameConfig({
    this.level = 1,
    this.mode = GameMode.coop,
    this.difficulty = Difficulty.calm,
    this.seed = 1,
    this.bonusPennies = 0,
    this.bonusLeaves = 0,
    this.summonDiscount = 0,
    this.dmgBonus = 0,
    this.hpScaleOverride = 0,
  });
}

/// Result of a player action, with a line for the UI when it fails.
class ActResult {
  final bool ok;
  final String msg;
  final UnitDef? unit;
  const ActResult(this.ok, [this.msg = '', this.unit]);
}

class Game {
  final GameConfig cfg;
  final math.Random rng;
  late final Field field;
  final List<PlayerSide> sides = [];
  final List<Enemy> enemies = [];
  final List<Enemy> _pending = [];
  final List<Fx> fx = [];
  final List<ChatLine> chat = [];
  double time = 0;
  int wave = 0;
  double waveTimer = 4; // grace before wave 1
  /// What the gate lets out next. A pair walks out together, one turning
  /// left and one right; a single (a mini-boss, the Pollock, the odd one out
  /// of an odd-sized wave) takes the next turning in [_nextSingleRoute].
  final List<({String id, bool pair})> _spawnQueue = [];
  int _nextSingleRoute = 0;
  double _spawnT = 0;

  /// The boss that leads the wave: the first twin still standing. Boss waves
  /// send two, one each way out of the gate; this stays set until both are
  /// down.
  Enemy? boss;

  /// Both twins of the current boss wave, dead or alive, in route order.
  /// Empty outside boss waves.
  final List<Enemy> bosses = [];
  double bossTimer = 0;
  GameStatus status = GameStatus.playing;
  String endReason = '';
  bool endless = false;
  int bossesKilled = 0;
  int _uid = 0;
  int _eid = 0;
  double _acc = 0;
  bool _brendaGift = false;
  int peakLane = 0;
  final Map<int, int> condemned = {}; // side -> cell (for UI)

  static const double step = 1 / 30;

  Game(this.cfg) : rng = math.Random(cfg.seed) {
    field = Field(cfg.mode);
    final p = kStartPennies + cfg.bonusPennies;
    sides.add(PlayerSide(0, p, cfg.bonusLeaves));
    if (cfg.mode == GameMode.coop) sides.add(PlayerSide(1, kStartPennies, 0));
  }

  PlayerSide get you => sides[0];
  PlayerSide? get partner => sides.length > 1 ? sides[1] : null;
  int get laneCount => enemies.where((e) => !e.dead).length;

  /// Health multiplier from mode + difficulty. The solo factor lives in
  /// [kSoloHpMultiplier].
  double hpScale({bool boss = false}) {
    final lv = levelDef(cfg.level).hpMult;
    if (cfg.hpScaleOverride > 0) {
      return cfg.hpScaleOverride * cfg.difficulty.hpMult * lv;
    }
    final m = cfg.mode == GameMode.solo
        ? kSoloHpMultiplier * (boss ? kSoloBossExtra : 1.0)
        : 1.0;
    return m * cfg.difficulty.hpMult * lv;
  }

  double enemyHp(String id, int w) =>
      baseHp(w) * kEnemyById[id]!.hpMult * hpScale() * kCrowdHpMult;
  double bossHp(int w) =>
      baseHp(w) *
      bossForWave(w, cfg.level).hpMult *
      hpScale(boss: true) *
      _endlessBossMult(w);
  double _endlessBossMult(int w) =>
      w > kFinalWave ? 1 + (w - kFinalWave) * 0.04 : 1;

  int summonCost(PlayerSide p) => math.max(
    10,
    kSummonBaseCost +
        kSummonStep * p.summons -
        (p.index == 0 ? cfg.summonDiscount : 0),
  );

  void say(String who, String text) {
    chat.add(ChatLine(who, text, time));
    if (chat.length > 30) chat.removeAt(0);
  }

  // ------------------------------------------------------------------
  // Main loop
  // ------------------------------------------------------------------
  void update(double dt) {
    if (status != GameStatus.playing) return;
    _acc += math.min(dt, 0.25);
    while (_acc >= step) {
      _acc -= step;
      _tick(step);
      if (status != GameStatus.playing) break;
    }
  }

  void _tick(double dt) {
    time += dt;
    _waves(dt);
    _enemies(dt);
    for (final s in sides) {
      _sideAttacks(s, dt);
    }
    enemies.removeWhere((e) => e.dead);
    enemies.addAll(_pending);
    _pending.clear();
    if (_brendaGift) {
      _brendaGift = false;
      final r = freeSummon(you);
      if (r.ok) {
        say(
          kPartnerName,
          'Put a penny in for you, love. You got ${r.unit!.name}.',
        );
      }
    }
    final lc = laneCount;
    if (lc > peakLane) peakLane = lc;
    if (lc >= kLaneLimit) {
      _lose('The pier is overrun. $kLaneLimit sea things on the boardwalk.');
    }
    if (boss != null && !boss!.dead) {
      bossTimer -= dt;
      if (bossTimer <= 0) {
        _lose('${boss!.name} outstayed the season. Boss timer ran out.');
      }
    }
  }

  void _lose(String why) {
    if (status != GameStatus.playing) return;
    status = GameStatus.lost;
    endReason = why;
  }

  // ------------------------------------------------------------------
  // Waves
  // ------------------------------------------------------------------
  void _waves(double dt) {
    if (_spawnQueue.isNotEmpty) {
      _spawnT -= dt;
      if (_spawnT <= 0) {
        final next = _spawnQueue.removeAt(0);
        if (next.pair) {
          // Two at once, so the gap after them is two singles long: the
          // wave lets out the same number of sea things in the same time.
          _spawnT = kSpawnGap * 2;
          for (var r = 0; r < field.routeCount; r++) {
            _spawn(next.id, route: r);
          }
        } else {
          _spawnT = kSpawnGap;
          _spawn(next.id, route: _nextSingleRoute);
          _nextSingleRoute = (_nextSingleRoute + 1) % field.routeCount;
        }
      }
    }
    if (boss != null) return; // boss waves advance when the boss dies
    waveTimer -= dt;
    if (waveTimer <= 0) startNextWave();
  }

  void startNextWave() {
    if (wave >= kFinalWave && !endless) return;
    wave++;
    for (final s in sides) {
      final pay = waveWages(wave);
      s.pennies += pay;
      s.stats.pennyEarned += pay;
      if (wave % 5 == 0) s.leaves += 1;
    }
    if (isBossWave(wave)) {
      final b = bossForWave(wave, cfg.level);
      // Twins: one turns left out of the gate, one right. Their health is
      // set by kTwinBossHpShare.
      bosses.clear();
      final n = field.routeCount;
      for (var r = 0; r < n; r++) {
        final e = Enemy(
          _eid++,
          null,
          b,
          n == 1
              ? bossHp(wave)
              : bossHp(wave) * twinBossHpShare(cfg.mode, cfg.difficulty),
          field.routeBase(r),
          b.speed,
          b.armor,
          0,
        );
        e.mechT = 4 + r * _twinStagger(b.mech);
        enemies.add(e);
        bosses.add(e);
      }
      boss = bosses.first;
      bossTimer = kBossSeconds;
      waveTimer = kBossSeconds;
      say(b.name, b.entrance);
      fx.add(Fx(FxType.boss, text: b.name, color: b.color));
      fx.add(Fx(FxType.shake, size: 1.0));
      return;
    }
    waveTimer = kWaveSeconds;
    final pool = enemyPool(wave, cfg.level);
    final n = spawnCount(wave);
    // Same head count as ever, let out in matching pairs so both turnings
    // (in co-op, both boards) meet the same sea things. An odd one out walks
    // alone.
    for (var i = 0; i < n ~/ 2; i++) {
      _spawnQueue.add((id: pool[rng.nextInt(pool.length)], pair: true));
    }
    if (n.isOdd) {
      _spawnQueue.add((id: pool[rng.nextInt(pool.length)], pair: false));
    }
    if (isMiniBossWave(wave)) {
      _spawnQueue.insert(0, (id: 'bigdrip', pair: false));
    }
    if (wave >= 4 && rng.nextDouble() < 0.12) {
      _spawnQueue.insert(rng.nextInt(_spawnQueue.length), (
        id: 'pollock',
        pair: false,
      ));
    }
    _spawnT = 0;
  }

  /// How long after its twin a boss's first move comes, so the two don't
  /// fire the same trick at the same moment.
  double _twinStagger(BossMech m) => switch (m) {
    BossMech.brood => 6,
    BossMech.inspector => 0,
    BossMech.undertow => 4.5,
    BossMech.landlord => 0,
  };

  /// Sea things on the pier per route: [0] left of the gate, [1] right.
  List<int> laneCountByRoute() {
    final out = List.filled(field.routeCount, 0);
    for (final e in enemies) {
      if (!e.dead) out[field.routeOf(e.s)]++;
    }
    return out;
  }

  /// A sea thing at the gate on [route], or at [s] (a child spawned beside
  /// its parent, which keeps the parent's route).
  Enemy _spawn(String id, {double? s, double? traveled, int route = 0}) {
    final d = kEnemyById[id]!;
    final hp = enemyHp(id, math.max(1, wave));
    final e = Enemy(
      _eid++,
      d,
      null,
      hp,
      s ?? field.routeBase(route),
      d.speed * (1 + wave * 0.004),
      d.armor,
      d.evade,
    );
    if (traveled != null) e.traveled = traveled;
    _pending.add(e);
    return e;
  }

  // ------------------------------------------------------------------
  // Enemies
  // ------------------------------------------------------------------
  void _enemies(double dt) {
    for (final e in enemies) {
      if (e.dead) continue;
      if (e.hitFlash > 0) e.hitFlash -= dt;
      if (e.burnT > 0) {
        e.burnT -= dt;
        _damage(e, e.burnDps * dt, null, canEvade: false, quiet: true);
        if (e.dead) continue;
      }
      if (e.slowT > 0) {
        e.slowT -= dt;
        if (e.slowT <= 0) e.slowPct = 0;
      }
      if (e.curseT > 0) e.curseT -= dt;
      if (e.stunT > 0) e.stunT -= dt;
      if (e.freezeT > 0) e.freezeT -= dt;
      if (e.def?.healAura case final h? when h > 0) {
        for (final o in enemies) {
          if (o == e || o.dead || o.isBoss) continue;
          if ((o.s - e.s).abs() < 1.3) {
            o.hp = math.min(o.maxHp, o.hp + o.maxHp * h * dt);
          }
        }
      }
      if (e.isBoss) _bossMech(e, dt);
      var sp = e.speed;
      if (e.surgeT > 0) {
        e.surgeT -= dt;
        sp *= 2;
      }
      if (e.stunT > 0 || e.freezeT > 0) sp = 0;
      sp *= (1 - e.slowPct);
      e.s += sp * dt;
      e.traveled += sp * dt;
      final laps = (e.traveled / field.lap).floor();
      if (laps > e.laps) {
        e.laps = laps;
        // Rent is collected once per lap of the lead twin, not once per
        // twin. The loops are half as long in co-op as the old figure-eight
        // walk, so the cut is halved there to keep the same rent per minute.
        if (e.boss?.mech == BossMech.landlord && identical(e, boss)) {
          final cut = 0.15 * field.lap / _legacyLap;
          for (final p in sides) {
            final take = (p.pennies * cut).floor();
            p.pennies -= take;
          }
          say(
            e.name,
            cut >= 0.149
                ? 'Rent day. Fifteen percent, thank you.'
                : 'Rent day. Seven and a half percent, thank you. Twice.',
          );
          final pp = field.posAt(e.s);
          fx.add(
            Fx(
              FxType.text,
              x: pp.x,
              y: pp.y,
              text:
                  'RENT -${(cut * 100).toStringAsFixed(cut >= 0.149 ? 0 : 1)}%',
              color: 0xFFFF5E7E,
              size: 1.4,
            ),
          );
        }
      }
    }
  }

  void _bossMech(Enemy e, double dt) {
    final b = e.boss!;
    e.mechT -= dt;
    final pos = field.posAt(e.s);
    switch (b.mech) {
      case BossMech.brood:
        if (e.mechT <= 0) {
          // Each twin broods half as often: the same adds per minute.
          e.mechT = 6.0 * bosses.length.clamp(1, 2);
          for (var i = 0; i < 3; i++) {
            _spawn(b.spawn, s: e.s - 0.3 * i, traveled: e.traveled);
          }
          fx.add(
            Fx(FxType.text, x: pos.x, y: pos.y, text: 'BLOOP', color: b.color),
          );
        }
      case BossMech.inspector:
        e.slowPct = 0;
        e.stunT = 0;
        // One inspection for the pair, from whichever twin leads.
        if (!identical(e, boss)) break;
        if (e.mechT <= 0) {
          e.mechT = 7;
          _condemn();
        }
        for (final p in sides) {
          for (final c in p.cells) {
            if (c.disabled > 0) c.disabled -= dt;
          }
        }
        condemned.removeWhere(
          (side, cell) => sides[side].cells[cell].disabled <= 0,
        );
      case BossMech.undertow:
        if (e.diveT > 0) {
          e.diveT -= dt;
          e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.04 / 2.5 * dt);
          if (e.diveT <= 0) {
            e.surgeT = 3;
            fx.add(Fx(FxType.shake, size: 0.6));
          }
        } else if (e.mechT <= 0) {
          e.mechT = 9;
          e.diveT = 2.5;
          say(b.name, '...down...');
        }
      case BossMech.landlord:
        final frac = e.hp / e.maxHp;
        if ((e.phase == 0 && frac < 0.66) || (e.phase == 1 && frac < 0.33)) {
          e.phase++;
          e.shield = e.maxHp * 0.15;
          // Four Bailiffs a phase between the twins: two each.
          final calls = 4 ~/ bosses.length.clamp(1, 4);
          for (var i = 0; i < calls; i++) {
            final bb = _spawn(
              'bailiff',
              s: e.s - 0.4 * (i + 1),
              traveled: e.traveled,
            );
            bb.maxHp = baseHp(wave) * 1.5 * hpScale();
            bb.hp = bb.maxHp;
          }
          say(
            b.name,
            e.phase == 1
                ? 'Bailiffs! Escort these people off my property.'
                : 'Fine. FINE. Everybody out.',
          );
          fx.add(Fx(FxType.shake, size: 0.8));
        }
    }
  }

  /// Length of the old single loop (solo ring, or the co-op figure-eight).
  /// Rent and similar per-lap effects are scaled against it.
  double get _legacyLap =>
      cfg.mode == GameMode.solo ? field.lap : field.lap * 2;

  void _condemn() {
    var bestSide = -1, bestCell = -1;
    var best = 0.0;
    for (final p in sides) {
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (c.isEmpty || c.disabled > 0) continue;
        final v = c.units.fold(0.0, (a, u) => a + u.def.dps);
        if (v > best) {
          best = v;
          bestSide = p.index;
          bestCell = i;
        }
      }
    }
    if (bestSide < 0) return;
    sides[bestSide].cells[bestCell].disabled = 4;
    condemned[bestSide] = bestCell;
    final c = field.cellCenter(bestSide, bestCell);
    fx.add(Fx(FxType.condemn, x: c.x, y: c.y));
    final who = sides[bestSide].cells[bestCell].def!.name;
    say('The Pier Inspector', '$who is CONDEMNED. Pending review.');
  }

  // ------------------------------------------------------------------
  // Figurines attacking
  // ------------------------------------------------------------------
  double dmgMult(PlayerSide p, UnitDef d) {
    var m = 1 + kUpgradeStep * p.upg[upgradeGroup(d.tier)];
    if (p.index == 0) m *= 1 + cfg.dmgBonus;
    return m;
  }

  /// Attack-speed bonus for a cell from auras and unions (0 = none).
  double speedBonus(PlayerSide p, int cellIdx, Set<String> unions) {
    final cell = p.cells[cellIdx];
    final d = cell.def;
    if (d == null) return 0;
    var bonus = 0.0;
    if (unions.contains('Birds') && d.tags.contains('Birds')) bonus += 0.2;
    final me = field.cellCenter(p.index, cellIdx);
    var bestTag = 0.0, bestAll = 0.0;
    for (var i = 0; i < p.cells.length; i++) {
      final c = p.cells[i];
      final a = c.def;
      if (a == null || a.auraTag == null || c.disabled > 0) continue;
      if (a.auraTag == 'all') {
        bestAll = math.max(bestAll, a.auraSpeed);
      } else if (d.tags.contains(a.auraTag) &&
          field.cellCenter(p.index, i).dist(me) <= a.auraRange) {
        bestTag = math.max(bestTag, a.auraSpeed);
      }
    }
    return bonus + bestTag + bestAll;
  }

  void _sideAttacks(PlayerSide p, double dt) {
    final unions = p.activeUnions();
    final birds = p.allUnits.where((u) => u.def.tags.contains('Birds')).length;
    for (var ci = 0; ci < p.cells.length; ci++) {
      final cell = p.cells[ci];
      if (cell.isEmpty) continue;
      if (cell.disabled > 0) continue;
      final d = cell.def!;
      final sb = speedBonus(p, ci, unions);
      final pos = field.cellCenter(p.index, ci);
      final range =
          d.range +
          (unions.contains('Sea') && d.tags.contains('Sea') ? 0.6 : 0);
      for (final u in cell.units) {
        if (d.freezeEvery > 0) {
          u.special += dt;
          if (u.special >= d.freezeEvery) {
            u.special = 0;
            _tideFreeze(p, d);
          }
        }
        u.cd -= dt * (1 + sb);
        if (u.cd > 0) continue;
        final targets = _targets(pos, range, d.pulse ? 999 : d.multi);
        if (targets.isEmpty) {
          u.cd = 0;
          continue;
        }
        u.cd += d.interval;
        u.attacks++;
        _attack(p, u, d, pos, targets, unions, birds);
      }
    }
  }

  List<Enemy> _targets(V2 pos, double range, int n) {
    final inRange = <Enemy>[];
    for (final e in enemies) {
      if (e.dead || e.submerged) continue;
      if (field.posAt(e.s).dist(pos) <= range) inRange.add(e);
    }
    if (inRange.length <= n) return inRange;
    inRange.sort((a, b) => b.traveled.compareTo(a.traveled));
    return inRange.sublist(0, n);
  }

  void _attack(
    PlayerSide p,
    UnitInst u,
    UnitDef d,
    V2 pos,
    List<Enemy> targets,
    Set<String> unions,
    int birds,
  ) {
    var dmg = d.dmg * dmgMult(p, d);
    if (unions.contains('Staff') && d.tags.contains('Staff')) dmg *= 1.2;
    if (d.perBird > 0) dmg *= 1 + d.perBird * birds;
    if (d.pennyScale > 0) {
      dmg += d.pennyScale * math.min(p.pennies, 1500) * dmgMult(p, d);
    }
    final sweets = unions.contains('Sweets') && d.tags.contains('Sweets');

    if (d.jackpotEvery > 0 && u.attacks % d.jackpotEvery == 0) {
      for (final e in _targets(pos, d.range + 1, 999)) {
        _damage(e, dmg * 10, p, unit: d);
      }
      p.pennies += 20;
      p.stats.pennyEarned += 20;
      fx.add(Fx(FxType.jackpot, x: pos.x, y: pos.y, color: d.color));
      fx.add(Fx(FxType.shake, size: 0.7));
      return;
    }
    if (d.pulse) {
      fx.add(
        Fx(FxType.pulse, x: pos.x, y: pos.y, size: d.range, color: d.color),
      );
    }

    final hitList = <Enemy>[...targets];
    if (d.chain > 0 && targets.isNotEmpty) {
      var last = targets.first;
      for (var k = 0; k < d.chain; k++) {
        Enemy? next;
        var bd = 1.6;
        final lp = field.posAt(last.s);
        for (final e in enemies) {
          if (e.dead || e.submerged || hitList.contains(e)) continue;
          final dd = field.posAt(e.s).dist(lp);
          if (dd < bd) {
            bd = dd;
            next = e;
          }
        }
        if (next == null) break;
        hitList.add(next);
        last = next;
      }
    }

    V2? prev;
    for (final t in hitList) {
      if (t.dead) continue;
      final tp = field.posAt(t.s);
      if (!d.pulse) {
        final from = (d.chain > 0 && prev != null) ? prev : pos;
        fx.add(
          Fx(
            d.tier.index >= 3 ? FxType.beam : FxType.shot,
            x: from.x,
            y: from.y,
            x2: tp.x,
            y2: tp.y,
            color: d.color,
            size: 1.0 + d.tier.index * 0.3,
          ),
        );
      }
      prev = tp;
      var hit = dmg;
      if (t.isBoss) hit *= d.bossMult;
      var crit = false;
      if (d.critChance > 0 && rng.nextDouble() < d.critChance) {
        hit *= d.critMult;
        crit = true;
      }
      final landed = _damage(t, hit, p, unit: d, crit: crit);
      if (!landed) continue;
      if (d.splash > 0) {
        for (final o in enemies) {
          if (o == t || o.dead || o.submerged) continue;
          if (field.posAt(o.s).dist(tp) <= d.splash) {
            _damage(o, hit * 0.6, p, unit: d, canEvade: false, quiet: true);
          }
          if (d.burnDps > 0 &&
              !o.dead &&
              field.posAt(o.s).dist(tp) <= d.splash) {
            _burn(o, p, d);
          }
          if (d.slowPct > 0 &&
              !o.dead &&
              field.posAt(o.s).dist(tp) <= d.splash) {
            _slow(o, d, sweets);
          }
        }
      }
      if (t.dead) continue;
      if (d.slowPct > 0) _slow(t, d, sweets);
      if (d.burnDps > 0) _burn(t, p, d);
      if (d.cursePct > 0) {
        t.cursePct = math.max(t.cursePct, d.cursePct);
        t.curseT = d.curseDur;
      }
      if (d.stunChance > 0 && rng.nextDouble() < d.stunChance) {
        if (t.boss?.mech != BossMech.inspector) {
          t.stunT = t.isBoss ? d.stunDur * 0.3 : d.stunDur;
        }
      }
      if (d.grabEvery > 0 && u.attacks % d.grabEvery == 0 && !t.isBoss) {
        t.s -= 1.5;
        t.traveled = math.max(0, t.traveled - 1.5);
        fx.add(
          Fx(FxType.text, x: tp.x, y: tp.y, text: 'YOINK', color: d.color),
        );
      }
      if (d.executePct > 0 && !t.isBoss && t.hp / t.maxHp < d.executePct) {
        _damage(
          t,
          t.hp + t.shield + 1,
          p,
          unit: d,
          canEvade: false,
          ignoreArmor: true,
          quiet: true,
        );
      }
    }
  }

  void _slow(Enemy e, UnitDef d, bool sweets) {
    if (e.boss?.mech == BossMech.inspector) return;
    var pct = d.slowPct * (sweets ? 1.5 : 1);
    var dur = d.slowDur * (sweets ? 1.5 : 1);
    if (e.isBoss) pct *= 0.5;
    e.slowPct = math.min(0.7, math.max(e.slowPct, pct));
    e.slowT = math.max(e.slowT, dur);
  }

  void _burn(Enemy e, PlayerSide p, UnitDef d) {
    e.burnDps = math.max(
      e.burnT > 0 ? e.burnDps : 0,
      d.burnDps * dmgMult(p, d),
    );
    e.burnT = d.burnDur;
  }

  void _tideFreeze(PlayerSide p, UnitDef d) {
    var any = false;
    for (final e in enemies) {
      if (e.dead) continue;
      any = true;
      final dur = e.isBoss ? 0.5 : d.freezeDur;
      e.freezeT = math.max(e.freezeT, dur);
      _damage(
        e,
        d.freezeDmg * dmgMult(p, d),
        p,
        unit: d,
        canEvade: false,
        quiet: true,
      );
    }
    if (any) {
      fx.add(Fx(FxType.freeze, color: d.color));
      fx.add(Fx(FxType.shake, size: 0.4));
    }
  }

  /// Returns false when the hit missed.
  bool _damage(
    Enemy e,
    double amount,
    PlayerSide? src, {
    UnitDef? unit,
    bool canEvade = true,
    bool ignoreArmor = false,
    bool crit = false,
    bool quiet = false,
  }) {
    if (e.dead || e.submerged) return false;
    if (canEvade && e.evade > 0 && rng.nextDouble() < e.evade) {
      if (!quiet) {
        final p = field.posAt(e.s);
        fx.add(Fx(FxType.miss, x: p.x, y: p.y));
      }
      return false;
    }
    var a = amount;
    if (e.curseT > 0) {
      a *= 1 + e.cursePct;
    } else if (!ignoreArmor) {
      a *= 1 - e.armor;
    }
    if (e.shield > 0) {
      final ab = math.min(e.shield, a);
      e.shield -= ab;
      a -= ab;
    }
    e.hp -= a;
    if (!quiet) {
      e.hitFlash = 0.1;
      if (crit || (e.isBoss && rng.nextDouble() < 0.15)) {
        final p = field.posAt(e.s);
        fx.add(
          Fx(
            FxType.hit,
            x: p.x,
            y: p.y,
            text: _fmt(a),
            color: crit ? 0xFFFFE066 : 0xFFFFFFFF,
            size: crit ? 1.3 : 0.9,
          ),
        );
      }
    }
    if (e.hp <= 0) _kill(e, src, unit);
    return true;
  }

  static String _fmt(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  void _kill(Enemy e, PlayerSide? src, UnitDef? unit) {
    if (e.dead) return;
    e.dead = true;
    final pos = field.posAt(e.s);
    final reward = killReward(wave);
    for (final p in sides) {
      p.pennies += reward;
      p.stats.pennyEarned += reward;
    }
    if (src != null) {
      src.stats.kills++;
      if (unit != null && unit.killPennies > 0) {
        src.pennies += unit.killPennies;
        src.stats.pennyEarned += unit.killPennies;
      }
      if (unit != null &&
          unit.tags.contains('Arcade') &&
          src.activeUnions().contains('Arcade')) {
        src.arcadeKills++;
        if (src.arcadeKills % 8 == 0) src.pennies++;
      }
    }
    fx.add(
      Fx(
        FxType.kill,
        x: pos.x,
        y: pos.y,
        color: e.boss?.color ?? e.def!.color,
        size: e.isBoss ? 3 : 1,
      ),
    );
    if (e.def?.id == 'pollock' && e.traveled < field.lap) {
      for (final p in sides) {
        p.leaves += 1;
        p.pennies += 15;
      }
      fx.add(
        Fx(
          FxType.text,
          x: pos.x,
          y: pos.y,
          text: '+1 LEAF',
          color: 0xFF9BE15D,
          size: 1.3,
        ),
      );
    }
    if (e.def?.splitInto case final sp?) {
      for (var i = 0; i < e.def!.splitCount; i++) {
        _spawn(sp, s: e.s - 0.25 * i, traveled: e.traveled);
      }
    }
    if (e.isBoss) _bossDown(e);
  }

  void _bossDown(Enemy e) {
    final standing = bosses.where((b) => !b.dead).toList();
    if (standing.isNotEmpty) {
      // One twin down. The wave isn't over until both are.
      final lead = boss!;
      boss = standing.first;
      // The Inspector's countdown carries on under the new lead.
      if (lead != boss && boss!.mechT > lead.mechT) boss!.mechT = lead.mechT;
      say(e.name, 'That\'s one of us. The other one\'s still on the pier.');
      fx.add(Fx(FxType.shake, size: 0.6));
      return;
    }
    bossesKilled++;
    say(e.name, e.boss!.defeat);
    fx.add(Fx(FxType.shake, size: 1.2));
    boss = null;
    bosses.clear();
    condemned.clear();
    for (final p in sides) {
      for (final c in p.cells) {
        c.disabled = 0;
      }
      p.leaves += 3;
      p.pennies += 40;
      p.stats.pennyEarned += 40;
    }
    if (wave >= kFinalWave && !endless) {
      status = GameStatus.won;
      endReason =
          '${bossForWave(kFinalWave, cfg.level).name} is gone. ${levelDef(cfg.level).name} is yours. Probably.';
      return;
    }
    // Brenda puts a penny in for you.
    if (partner != null) _brendaGift = true;
    waveTimer = 3;
  }

  /// Keep playing after the final boss.
  void goEndless() {
    endless = true;
    if (status == GameStatus.won) {
      status = GameStatus.playing;
      waveTimer = 3;
    }
  }

  // ------------------------------------------------------------------
  // Player actions
  // ------------------------------------------------------------------
  int newUid() => _uid++;

  Tier rollTier(int luck) {
    final odds = summonOdds(luck);
    var r = rng.nextDouble() * 100;
    for (var i = 0; i < 4; i++) {
      r -= odds[i];
      if (r < 0) return Tier.values[i];
    }
    return Tier.common;
  }

  UnitDef randomOfTier(Tier t, {String? except}) {
    final list = unitsOfTier(t).where((u) => u.id != except).toList();
    return list[rng.nextInt(list.length)];
  }

  /// Put a figurine on the board: join a matching stack, else an empty cell.
  int place(PlayerSide p, UnitDef d, {int prefer = -1}) {
    var best = -1;
    for (var i = 0; i < p.cells.length; i++) {
      final c = p.cells[i];
      if (!c.isEmpty && c.def!.id == d.id && c.units.length < kStackMax) {
        if (best < 0 || c.units.length > p.cells[best].units.length) best = i;
      }
    }
    if (best < 0 && prefer >= 0 && p.cells[prefer].isEmpty) best = prefer;
    if (best < 0) {
      // Fill the cells that see the most lane first.
      for (final i in field.placeOrder[p.index]) {
        if (p.cells[i].isEmpty) {
          best = i;
          break;
        }
      }
    }
    if (best < 0) return -1;
    p.cells[best].units.add(UnitInst(d, newUid(), time));
    p.seen.add(d.id);
    p.got[d.id] = (p.got[d.id] ?? 0) + 1;
    return best;
  }

  ActResult summon(PlayerSide p) {
    final cost = summonCost(p);
    if (p.pennies < cost) return ActResult(false, 'Need $cost pennies.');
    if (!p.hasEmptyCell) {
      return const ActResult(
        false,
        'No room on the board. Merge or sell something.',
      );
    }
    p.pennies -= cost;
    p.summons++;
    p.stats.summons++;
    var t = rollTier(p.luck);
    // The Machine's Mercy: seven commons in a row and the next is Rare or better.
    if (t == Tier.common) {
      p.dryStreak++;
      if (p.dryStreak >= kMercyStreak) t = Tier.rare;
    }
    if (t != Tier.common) p.dryStreak = 0;
    return _summonInto(p, t);
  }

  /// A summon that costs nothing and does not raise the price.
  ActResult freeSummon(PlayerSide p) {
    if (!p.hasEmptyCell) return const ActResult(false, 'No room.');
    return _summonInto(p, rollTier(p.luck));
  }

  ActResult _summonInto(PlayerSide p, Tier t) {
    final d = randomOfTier(t);
    final cell = place(p, d);
    final c = field.cellCenter(p.index, cell);
    fx.add(
      Fx(
        FxType.summon,
        x: c.x,
        y: c.y,
        color: t.color,
        size: t.index.toDouble(),
        text: d.id,
      ),
    );
    return ActResult(true, '', d);
  }

  bool canMerge(PlayerSide p, int cell) {
    final c = p.cells[cell];
    return c.units.length == kStackMax &&
        c.def!.tier.index < Tier.legendary.index;
  }

  ActResult merge(PlayerSide p, int cell) {
    if (!canMerge(p, cell)) {
      return const ActResult(false, 'Need three of the same (Epic or lower).');
    }
    final c = p.cells[cell];
    final next = Tier.values[c.def!.tier.index + 1];
    c.units.clear();
    final d = randomOfTier(next);
    final at = place(p, d, prefer: cell);
    p.stats.merges++;
    final cc = field.cellCenter(p.index, at);
    fx.add(
      Fx(
        FxType.merge,
        x: cc.x,
        y: cc.y,
        color: next.color,
        size: next.index.toDouble(),
        text: d.id,
      ),
    );
    return ActResult(true, '', d);
  }

  bool canCraft(PlayerSide p, String mythicId) {
    final r = kRecipes[mythicId]!;
    return r.every((id) => p.countOf(id) > 0);
  }

  ActResult craft(PlayerSide p, String mythicId) {
    if (!canCraft(p, mythicId)) {
      return const ActResult(false, 'Missing ingredients.');
    }
    var freed = -1;
    for (final id in kRecipes[mythicId]!) {
      // take from the smallest stack
      var idx = -1;
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (!c.isEmpty &&
            c.def!.id == id &&
            (idx < 0 || c.units.length < p.cells[idx].units.length)) {
          idx = i;
        }
      }
      p.cells[idx].units.removeLast();
      if (p.cells[idx].isEmpty) freed = idx;
    }
    final d = kUnitById[mythicId]!;
    final at = place(p, d, prefer: freed);
    p.stats.mythics++;
    final cc = field.cellCenter(p.index, at);
    fx.add(
      Fx(FxType.mythic, x: cc.x, y: cc.y, color: d.color, size: 4, text: d.id),
    );
    fx.add(Fx(FxType.shake, size: 0.8));
    say(d.name, d.quip);
    return ActResult(true, '', d);
  }

  ActResult sell(PlayerSide p, int cell) {
    final c = p.cells[cell];
    if (c.isEmpty) return const ActResult(false);
    final d = c.def!;
    if (d.tier == Tier.mythic) {
      return const ActResult(false, 'Mythics are not for sale.');
    }
    c.units.removeLast();
    p.pennies += sellPennies(d.tier);
    p.leaves += sellLeaves(d.tier);
    p.stats.sold++;
    final cc = field.cellCenter(p.index, cell);
    fx.add(Fx(FxType.sell, x: cc.x, y: cc.y, color: d.tier.color));
    return ActResult(true, '', d);
  }

  /// (pennies, leaves) to reroll one figurine of this tier.
  (int, int) rerollCost(Tier t) => switch (t) {
    Tier.common || Tier.rare => (kRerollPennies, 0),
    Tier.epic => (0, 1),
    Tier.legendary => (0, 2),
    Tier.mythic => (0, 99),
  };

  ActResult reroll(PlayerSide p, int cell) {
    final c = p.cells[cell];
    if (c.isEmpty) return const ActResult(false);
    final d = c.def!;
    if (d.tier == Tier.mythic) {
      return const ActResult(false, 'Mythics cannot be shaken.');
    }
    final (cp, cl) = rerollCost(d.tier);
    if (p.pennies < cp || p.leaves < cl) {
      return ActResult(
        false,
        cl > 0 ? 'Need $cl tea leaves.' : 'Need $cp pennies.',
      );
    }
    p.pennies -= cp;
    p.leaves -= cl;
    c.units.removeLast();
    final nd = randomOfTier(d.tier, except: d.id);
    final at = place(p, nd, prefer: cell);
    p.stats.rerolls++;
    final cc = field.cellCenter(p.index, at);
    fx.add(
      Fx(
        FxType.summon,
        x: cc.x,
        y: cc.y,
        color: nd.tier.color,
        size: nd.tier.index.toDouble(),
        text: nd.id,
      ),
    );
    return ActResult(true, '', nd);
  }

  ActResult gamble(PlayerSide p, GambleOption g) {
    if (p.leaves < g.cost) {
      return ActResult(
        false,
        'Need ${g.cost} tea leaf${g.cost > 1 ? 'es' : ''}.',
      );
    }
    if (!p.hasEmptyCell) return const ActResult(false, 'No room on the board.');
    p.leaves -= g.cost;
    p.stats.gambles++;
    if (rng.nextDouble() < g.chance) {
      p.stats.gambleWins++;
      final r = _summonInto(p, g.tier);
      fx.add(Fx(FxType.gamble, color: g.tier.color, text: 'win'));
      return r;
    }
    fx.add(Fx(FxType.gamble, color: 0xFF666666, text: 'lose'));
    return const ActResult(false, 'The leaves say: no.');
  }

  ActResult upgrade(PlayerSide p, int group) {
    final lvl = p.upg[group];
    if (lvl >= kMaxUpgrade) return const ActResult(false, 'Maxed.');
    final cost = upgradeCost(group, lvl);
    if (p.pennies < cost) return ActResult(false, 'Need $cost pennies.');
    p.pennies -= cost;
    p.upg[group]++;
    p.stats.upgrades++;
    return const ActResult(true);
  }

  ActResult upgradeLuck(PlayerSide p) {
    if (p.luck >= kMaxLuck) {
      return const ActResult(false, 'As lucky as it gets.');
    }
    final cost = luckUpgradeCost(p.luck);
    if (p.pennies < cost) return ActResult(false, 'Need $cost pennies.');
    p.pennies -= cost;
    p.luck++;
    return const ActResult(true);
  }

  /// Swap two cells (drag to rearrange).
  void swap(PlayerSide p, int a, int b) {
    if (a == b) return;
    final ua = [...p.cells[a].units];
    final ub = [...p.cells[b].units];
    final da = p.cells[a].disabled;
    p.cells[a].units
      ..clear()
      ..addAll(ub);
    p.cells[b].units
      ..clear()
      ..addAll(ua);
    p.cells[a].disabled = p.cells[b].disabled;
    p.cells[b].disabled = da;
  }

  /// Co-op: hand one figurine to Brenda.
  ActResult gift(int cell) {
    final mate = partner;
    if (mate == null) return const ActResult(false);
    final c = you.cells[cell];
    if (c.isEmpty) return const ActResult(false);
    final d = c.def!;
    final fits = mate.cells.any((x) => x.canTake(d));
    if (!fits) return const ActResult(false, 'Brenda has no room.');
    c.units.removeLast();
    place(mate, d);
    say(kPartnerName, 'Ooh, ${d.name}! For me? You shouldn\'t have.');
    return ActResult(true, '', d);
  }

  /// Total damage-per-second of a side, before situational effects.
  double sideDps(PlayerSide p) =>
      p.allUnits.fold(0.0, (a, u) => a + u.def.dps * dmgMult(p, u.def));
}
