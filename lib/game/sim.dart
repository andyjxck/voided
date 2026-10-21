// Pier Pressure — the simulation. Pure Dart, deterministic for a seed, no
// Flutter imports, so tests and balance sims can run thousands of waves fast.

import 'dart:math' as math;

import 'data.dart';

part 'mech.dart';
part 'rules.dart';

class V2 {
  final double x, y;
  const V2(this.x, this.y);
  double dist(V2 o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
}

/// Field geometry, in cell units. Solo: one loop around your board.
/// Co-op: an S-shaped loop: around Brenda's board, along the shared middle
/// boardwalk, around yours, and along the middle again. Both boards reach the
/// middle, which is where co-op earns its keep.
class Field {
  final GameMode mode;
  late final double w;
  late final double h;

  /// Distance that counts as one trip round, on either route.
  late final double lap;

  /// How far apart the two lanes run: they never come closer than this.
  static const double laneGap = 0.44;

  /// Length of the route loops, for [posAt].
  double routeLength(int r) => _cums[r].last;

  /// Distance that counts as a "lap" for lap-end traits (rent, thieves,
  /// the Unmaker). Co-op routes are half the old figure-eight, so a lap
  /// there is two trips round, keeping the plan's pacing.
  late final double cycle;

  /// The Hatch: where everything climbs out, in the middle of the map.
  late final V2 hatch;

  /// Route 0 heads left out of the Hatch, route 1 heads right. Every
  /// wave comes out in twins, one on each.
  late final List<List<V2>> routes;
  late final List<List<double>> _cums;
  Field(this.mode) {
    w = kBoardCols + 2.0;
    final a = w - 0.5;
    final cx = w / 2;
    if (mode == GameMode.solo) {
      h = kBoardRows + 2.0;
      hatch = V2(cx, 0.5);
      // Two lanes round the one board so the twins pass instead of walking
      // through each other: left-first on the inside, right-first on the
      // outside, laneGap apart (from the centre-gate spawning work).
      const i = 0.5 + laneGap / 2, o = 0.5 - laneGap / 2;
      routes = [
        [
          V2(cx, i),
          const V2(i, i),
          V2(i, h - i),
          V2(w - i, h - i),
          V2(w - i, i),
        ],
        [
          V2(cx, o),
          V2(w - o, o),
          V2(w - o, h - o),
          V2(o, h - o),
          const V2(o, o),
        ],
      ];
    } else {
      h = kBoardRows * 2 + 3.0;
      final mid = kBoardRows + 1.5;
      const o = laneGap / 2;
      hatch = V2(cx, mid);
      routes = [
        // left, then round Brenda's board at the top
        [
          V2(cx, mid - o),
          V2(0.5, mid - o),
          const V2(0.5, 0.5),
          V2(a, 0.5),
          V2(a, mid - o),
        ],
        // right, then round your board at the bottom
        [
          V2(cx, mid + o),
          V2(a, mid + o),
          V2(a, h - 0.5),
          V2(0.5, h - 0.5),
          V2(0.5, mid + o),
        ],
      ];
    }
    _cums = [];
    for (final pts in routes) {
      final cum = <double>[0];
      for (var i = 0; i < pts.length; i++) {
        cum.add(cum.last + pts[i].dist(pts[(i + 1) % pts.length]));
      }
      _cums.add(cum);
    }
    // Solo's outside lane is longer than the inside one; [posAt] stretches
    // each route onto the shared lap, so twins stay level (the outside one
    // simply walks a little faster) and s % lap keeps meaning progress.
    lap = (_cums[0].last + _cums[1].last) / 2;
    cycle = mode == GameMode.solo ? lap : lap * 2;
  }

  /// The Hatch, under the name the drawing code uses.
  V2 get gate => hatch;

  /// The boardwalk loops to draw: one per route.
  List<List<V2>> get walks => routes;

  /// Corner points of route 0 (kept for older callers).
  List<V2> get pts => routes[0];

  /// The side whose board route [r] runs round.
  int sideOfRoute(int r) => mode == GameMode.solo ? 0 : (r == 0 ? 1 : 0);

  /// Board top-left for side [i]. Side 0 is always the human player (bottom).
  V2 boardOrigin(int i) {
    if (mode == GameMode.solo) return const V2(1, 1);
    return i == 0 ? V2(1, kBoardRows + 2.0) : const V2(1, 1);
  }

  V2 cellCenter(int side, int cell) {
    final o = boardOrigin(side);
    return V2(o.x + cell % kBoardCols + 0.5, o.y + cell ~/ kBoardCols + 0.5);
  }

  V2 at(Enemy e) => posAt(e.s, e.route);

  V2 posAt(double s, [int route = 0]) {
    final pts = routes[route];
    final cum = _cums[route];
    // Before the Hatch (s < 0) things wait in it.
    if (s < 0) return pts[0];
    final t = (s % lap) * cum.last / lap;
    var i = 0;
    while (i < pts.length - 1 && cum[i + 1] <= t) {
      i++;
    }
    final p0 = pts[i], p1 = pts[(i + 1) % pts.length];
    final segLen = cum[i + 1] - cum[i];
    final f = segLen <= 0 ? 0.0 : (t - cum[i]) / segLen;
    return V2(p0.x + (p1.x - p0.x) * f, p0.y + (p1.y - p0.y) * f);
  }

  /// Fraction of the lap within [r] of a cell: how good a spot it is.
  double coverage(int side, int cell, [double r = 2.8]) {
    const n = 200;
    var hit = 0;
    final c = cellCenter(side, cell);
    for (final route in [0, 1]) {
      for (var i = 0; i < n; i++) {
        if (posAt(lap * i / n, route).dist(c) <= r) hit++;
      }
    }
    return hit / (2 * n);
  }

  late final List<List<int>> placeOrder = [
    for (var side = 0; side < (mode == GameMode.solo ? 1 : 2); side++)
      (List.generate(kBoardCols * kBoardRows, (i) => i)
        ..sort((x, y) => coverage(side, y).compareTo(coverage(side, x)))),
  ];
}

class UnitInst {
  double abilT = 0;
  int hits = 0;
  Enemy? rampOn;
  double rampT = 0;
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

  /// Brass Bandsman cover: can't be disabled or grabbed.
  double protectT = 0;

  /// Cuttle's ink: half range. Lantern Fish flash: half speed.
  double inkT = 0, flashT = 0;

  /// The Lighthouse beam: 20% faster.
  double beamT = 0;

  /// Static: the wave this cell stops flickering (0 = not flickering).
  int flicker = 0;

  /// Lampmoths sitting on this cell.
  int moths = 0;
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

  /// Bonds switched on this tick, and what each cell gets from them.
  List<ActiveBond> bonds = const [];
  List<BondMod?> bondMods = List<BondMod?>.filled(
    kBoardCols * kBoardRows,
    null,
  );

  /// Bonds that would be on if the Severer had not cut them.
  List<ActiveBond> bondsWaiting = const [];

  /// House rule payouts this run.
  int interestPaid = 0, sweeps = 0, quickKills = 0;

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
  /// Unions the Redactor has crossed out, with seconds left.
  final Map<String, double> redacted = {};

  /// How many different members of [tag] are on the board.
  int unionSize(String tag) {
    final ids = <String>{};
    for (final c in cells) {
      if (!c.isEmpty && c.def!.tags.contains(tag)) ids.add(c.def!.id);
    }
    return ids.length;
  }

  Set<String> activeUnions() {
    final byTag = <String, Set<String>>{};
    for (final u in allUnits) {
      for (final t in u.def.tags) {
        (byTag[t] ??= <String>{}).add(u.def.id);
      }
    }
    return {
      for (final e in byTag.entries)
        if (e.value.length >= 3 && !redacted.containsKey(e.key)) e.key,
    };
  }
}

class Enemy {
  // ---- content-plan state (see mech.dart) ----
  int weight = 1;
  double revealT = 0, litT = 0, stickyT = 0, noHealT = 0, markT = 0;
  double markPct = 0, inkT = 0, stripT = 0, immuneT = 0, traitT = 0;
  double tunnelT = 0, clampT = 0, puff = 0, bareT = 0, pairDue = 0;
  int shellHits = 0, stacks = 0, stolen = 0, knifeMiss = 0, carriages = 0;
  int latchSide = -1, latchCell = -1, pairId = -1, group = -1, resist = -1;
  bool tin = false, form2 = false, rammed = false, shellUsed = false;
  bool isCopy = false;
  Trait copied = Trait.none;
  Enemy? trainOf;

  /// 0 = came out of the Hatch heading left, 1 = heading right.
  int route = 0;

  /// For twinned bosses: the one that runs the board-wide moves.
  bool twinLead = true;

  /// A move a boss has lined up (a column, a clamp), or -1.
  int pending = -1;

  /// Octo-Tot ink cloud: dodges 25% more.
  double cloudT = 0;

  /// The kind of the last hit, for the Mirrorling.
  int lastKind = 0;

  /// When this was last healed (heals don't stack).
  double healedAt = -1;
  final List<double> hurtBy = [0, 0, 0];
  Trait get trait => def?.trait ?? Trait.none;

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
  final List<String> _spawnQueue = [];
  double _spawnT = 0;
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

  /// Seconds left on the Severer's cut: no bonds anywhere while above 0.
  double bondsCut = 0;

  /// Rift Drummers alive this tick.
  List<Enemy> drummers = const [];

  // ---- content-plan state (see mech.dart) ----
  final List<Tell> tells = [];

  /// Lines for the screen reader (and the alert strip), oldest first.
  final List<String> alerts = [];
  bool _lampAll = false;
  double fogT = 0, fogA = 0;
  double beamT = 10;
  bool beamWarned = false;
  int beamHalf = 0;
  bool tideHigh = false;
  double lanternT = 0;
  int lanternHits = 0;
  V2 lanternPos = const V2(0, 0);
  bool limpetClamped = false;
  bool spenderAlive = false;
  final Map<int, int> ponyLost = {};
  int unmadeThisWave = 0;
  String? act;
  String? redactPending;
  int clawSide = -1, clawCell = -1, clawFrom = 0;
  double clawT = 0, clawHp = 0, clawHold = 0;
  UnitInst? clawHeld;
  int laneLimit = kLaneLimit;

  /// Every boss out on this wave (twins included).
  final List<Enemy> bossList = [];
  int _starOpen = -1;
  bool _broodFlip = false;
  int _ponyCount = 0, _ponyGroup = 0;

  /// The boss whose bar shows: the lead twin while it lives.
  Enemy? get boss {
    for (final b in bossList) {
      if (!b.dead && b.twinLead) return b;
    }
    for (final b in bossList) {
      if (!b.dead) return b;
    }
    return null;
  }

  /// Every boss still standing.
  /// Every boss of this wave, dead or alive (the name the UI uses).
  List<Enemy> get bosses => bossList;

  List<Enemy> get bossesAlive => [
    for (final b in bossList)
      if (!b.dead) b,
  ];

  /// Combined health of every boss out, for the boss bar.
  double get bossHpLeft => bossesAlive.fold(0.0, (a, b) => a + b.hp);
  double get bossHpMax => bossList.fold(0.0, (a, b) => a + b.maxHp);

  void tell(
    String label, {
    double x = -1,
    double y = -1,
    double r = 0.6,
    int side = -1,
    int cell = -1,
    double dur = 2,
    int color = 0xFFFFD166,
    bool alert = true,
  }) {
    tells.add(
      Tell(
        label,
        color: color,
        x: x,
        y: y,
        r: r,
        side: side,
        cell: cell,
        dur: dur,
      ),
    );
    if (tells.length > 24) tells.removeAt(0);
    if (alert) {
      alerts.add(label);
      if (alerts.length > 20) alerts.removeAt(0);
    }
  }

  static const double step = 1 / 30;

  Game(this.cfg) : rng = math.Random(cfg.seed) {
    field = Field(cfg.mode);
    final p = kStartPennies + cfg.bonusPennies;
    sides.add(PlayerSide(0, p, cfg.bonusLeaves));
    if (cfg.mode == GameMode.coop) sides.add(PlayerSide(1, kStartPennies, 0));
  }

  PlayerSide get you => sides[0];
  PlayerSide? get partner => sides.length > 1 ? sides[1] : null;

  /// Riftlings on the pier, by weight (a Plushie Pile counts as 3).
  int get laneCount =>
      enemies.fold(0, (a, e) => e.dead ? a : a + (e.def?.weight ?? 1));

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
    _mechTick(dt);
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
    if (lc >= laneLimit) {
      _lose('The Rift is overrun. $laneLimit riftlings loose.');
    }
    if (boss != null) {
      bossTimer -= dt;
      if (bossTimer <= 0) {
        _lose('${boss!.name} held the Rift open. Boss timer ran out.');
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
        _spawnT = 0.75;
        _spawnTwins(_spawnQueue.removeAt(0));
      }
    }
    if (boss != null) return; // boss waves advance when every boss is down
    waveTimer -= dt;
    if (waveTimer <= 0) {
      // Calm, waves 19-49: give a crowded board a breather before the next
      // wave (see kPaceCrowd), so bosses don't arrive behind a pile.
      if (cfg.difficulty == Difficulty.calm &&
          wave >= kPaceFrom &&
          wave <= kPaceTo &&
          paceHeld < kPaceHoldMax &&
          (_spawnQueue.isNotEmpty || enemies.length > kPaceCrowd)) {
        paceHeld += dt;
        return;
      }
      startNextWave();
    }
  }

  /// Seconds the current wave has been held open by the Calm pacing.
  double paceHeld = 0;

  void startNextWave() {
    if (wave >= kFinalWave && !endless) return;
    wave++;
    unmadeThisWave = 0;
    paceHeld = 0;
    payWaveRules();
    for (final s in sides) {
      final pay = waveWages(wave);
      s.pennies += pay;
      s.stats.pennyEarned += pay;
      if (wave % 5 == 0) s.leaves += 1;
    }
    _ruleWave(wave);
    if (isBossWave(wave)) {
      bossList.clear();
      final defs = bossesForWave(wave, cfg.level);
      final share = defs.length > 1 ? 0.6 : 1.0;
      for (final b in defs) {
        // Bosses come out of the Hatch in twins too: one heads left, one
        // heads right, each with half the health.
        // Second forms move faster (see _mechRate), so they carry a little
        // less health.
        final form2 = isSecondForm(wave);
        final f2 = form2 ? kSecondFormHp : 1.0;
        for (final route in [0, 1]) {
          final e = _spawnBoss(b, scale: share * f2 * 0.5, route: route);
          e.twinLead = route == 0;
          e.form2 = form2;
        }
        say(b.name, b.entrance);
        fx.add(Fx(FxType.boss, text: b.name, color: b.color));
        tell(
          '${b.name} climbs out of the Hatch, twice',
          dur: 2,
          color: b.color,
        );
      }
      bossTimer = kBossSeconds;
      waveTimer = kBossSeconds;
      fx.add(Fx(FxType.shake, size: 1.0));
      return;
    }
    waveTimer = kWaveSeconds;
    _spawnQueue.addAll(_composeWave(wave));
    final elite = kLevelElite[((cfg.level - 1) % kLevels.length) + 1];
    if (isMiniBossWave(wave) && elite != null) _spawnQueue.insert(0, elite);
    if (wave >= 4 && rng.nextDouble() < 0.12) {
      _spawnQueue.insert(rng.nextInt(_spawnQueue.length), 'pollock');
    }
    _spawnT = 0;
  }

  /// A boss at [scale] of this wave's boss health, on [route].
  Enemy _spawnBoss(BossDef b, {double scale = 1, double s = 0, int route = 0}) {
    final hp =
        baseHp(math.max(1, wave)) *
        b.hpMult *
        hpScale(boss: true) *
        _endlessBossMult(wave) *
        kBossHpScale *
        scale;
    final e = Enemy(_eid++, null, b, hp, s, b.speed, b.armor, 0);
    e.route = route;
    e.mechT = 4;
    _pending.add(e);
    bossList.add(e);
    if (b.mech == BossMech.ghosttrain) {
      e.carriages = 5;
      for (var k = 1; k <= 5; k++) {
        final c = _spawn(
          'carriage',
          route: route,
          s: s - 0.45 * k,
          traveled: 0,
        );
        c.maxHp = hp * 0.12;
        c.hp = c.maxHp;
        c.trainOf = e;
      }
    }
    return e;
  }

  /// One of everything for each route, out of the Hatch together.
  void _spawnTwins(String id) {
    final star = id == 'star';
    var pairBase = -1;
    if (star) {
      if (_starOpen < 0) {
        _starOpen = _eid;
        pairBase = _starOpen;
      } else {
        pairBase = _starOpen;
        _starOpen = -1;
      }
    }
    var group = -1;
    if (id == 'pony') {
      if (_ponyCount % 4 == 0) _ponyGroup++;
      _ponyCount++;
      group = _ponyGroup;
    }
    for (final route in [0, 1]) {
      final e = _spawn(id, route: route);
      if (star) e.pairId = pairBase * 2 + route;
      if (group >= 0) e.group = group * 2 + route;
    }
    final h = field.hatch;
    fx.add(Fx(FxType.pulse, x: h.x, y: h.y, size: 0.5, color: 0x66A98467));
  }

  Enemy _spawn(String id, {double s = 0, double? traveled, int route = 0}) {
    final d = kEnemyById[id]!;
    final hp = enemyHp(id, math.max(1, wave));
    final e = Enemy(
      _eid++,
      d,
      null,
      hp,
      s,
      d.speed * (1 + wave * 0.004),
      d.armor,
      d.evade,
    );
    e.route = route;
    if (traveled != null) e.traveled = traveled;
    switch (d.trait) {
      case Trait.shell:
        e.shellHits = 6;
      case Trait.tin:
        // The tin is the armour: curse it and it bolts, unarmoured.
        e.tin = true;
        e.armor = 0;
      case Trait.spender:
        spenderAlive = true;
      default:
        break;
    }
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
        _damage(
          e,
          e.burnDps * dt,
          null,
          canEvade: false,
          quiet: true,
          kind: kHitStatus,
        );
        if (e.dead) continue;
      }
      if (e.slowT > 0) {
        e.slowT -= dt;
        if (e.slowT <= 0) e.slowPct = 0;
      }
      if (e.curseT > 0) e.curseT -= dt;
      if (e.stunT > 0) e.stunT -= dt;
      if (e.freezeT > 0) e.freezeT -= dt;
      if (e.cloudT > 0) e.cloudT -= dt;
      _pairCheck(e);
      if (e.def?.healAura case final h?
          when h > 0 && e.trait != Trait.heal && e.trait != Trait.lure) {
        for (final o in enemies) {
          if (o == e || o.dead || o.isBoss) continue;
          // Burning or Watched things can't be healed.
          if (o.burnT > 0 || o.noHealT > 0) continue;
          if (o.healedAt == time) continue;
          if (o.route == e.route && (o.s - e.s).abs() < 1.3) {
            o.healedAt = time;
            o.hp = math.min(o.maxHp, o.hp + o.maxHp * h * dt);
          }
        }
      }
      if (e.isBoss) {
        if (e.twinLead || _bodyMech(e.boss!.mech)) {
          _bossMech(e, dt);
        } else {
          e.mechT -= dt;
        }
      }
      var sp = e.speed * _traitTick(e, dt);
      if (e.surgeT > 0) {
        e.surgeT -= dt;
        sp *= 2;
      }
      if (e.stunT > 0 || e.freezeT > 0) sp = 0;
      sp *= (1 - e.slowPct);
      e.s += sp * dt;
      e.traveled += sp * dt;
      final laps = (e.traveled / field.cycle).floor();
      if (laps > e.laps) {
        e.laps = laps;
        _onLap(e);
        if (e.boss?.mech == BossMech.landlord && e.twinLead) {
          for (final p in sides) {
            final take = (p.pennies * 0.15).floor();
            p.pennies -= take;
          }
          say(e.name, 'Rent day. Fifteen percent, thank you.');
          final pp = field.at(e);
          fx.add(
            Fx(
              FxType.text,
              x: pp.x,
              y: pp.y,
              text: 'RENT -15%',
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
    final pos = field.at(e);
    switch (b.mech) {
      case BossMech.brood:
        if (e.mechT <= 0) {
          e.mechT = 6;
          // Only the lead twin runs this, so batches take turns between the
          // twins (centre-gate rule): each side faces its own helpers and the
          // total stays the same.
          Enemy from = e;
          if (_broodFlip) {
            for (final o in bossList) {
              if (o != e && o.boss == e.boss && !o.dead) from = o;
            }
          }
          _broodFlip = !_broodFlip;
          for (var i = 0; i < 3; i++) {
            _spawn(
              b.spawn,
              route: from.route,
              s: from.s - 0.3 * i,
              traveled: from.traveled,
            );
          }
          fx.add(
            Fx(FxType.text, x: pos.x, y: pos.y, text: 'BLOOP', color: b.color),
          );
        }
      case BossMech.inspector:
        e.slowPct = 0;
        e.stunT = 0;
        if (e.mechT <= 0) {
          e.mechT = 7;
          _condemn();
        }
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
          for (var i = 0; i < 4; i++) {
            final bb = _spawn(
              'bailiff',
              route: e.route,
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
      default:
        _bossMech2(e, dt);
    }
  }

  /// Boss moves that belong to its own body (diving, clamping, tunnels,
  /// gravity), which both twins do. Everything board-wide is the lead's.
  bool _bodyMech(BossMech m) => const {
    BossMech.undertow,
    BossMech.limpet,
    BossMech.ghosttrain,
    BossMech.voidboss,
  }.contains(m);

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
    say('The Rift Inspector', '$who is CONDEMNED. Pending review.');
  }

  // ------------------------------------------------------------------
  // Figurines attacking
  // ------------------------------------------------------------------
  double dmgMult(PlayerSide p, UnitDef d) {
    var m = 1 + kUpgradeStep * p.upg[upgradeGroup(d.tier)];
    if (p.index == 0) m *= 1 + cfg.dmgBonus;
    m *= 1 + hoardBonus(p);
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
    refreshBonds(p);
    for (var ci = 0; ci < p.cells.length; ci++) {
      final cell = p.cells[ci];
      if (cell.isEmpty) continue;
      if (!_cellWorks(cell)) continue;
      final d = cell.def!;
      final bond = p.bondMods[ci];
      var sb = speedBonus(p, ci, unions) + fullStackBonus(cell);
      if (bond != null) sb += bond.spd;
      if (cell.beamT > 0) sb += 0.2;
      final pos = field.cellCenter(p.index, ci);
      var range =
          d.range +
          (unions.contains('Sea') && d.tags.contains('Sea') ? 0.6 : 0) +
          (bond?.range ?? 0);
      if (cell.inkT > 0) range *= 0.5;
      var slowCell = 1.0;
      if (cell.flashT > 0) slowCell *= 0.5;
      if (cell.flicker > 0) slowCell *= 0.75;
      final single = d.multi <= 1 && d.splash <= 0 && !d.pulse && d.chain == 0;
      for (final u in cell.units) {
        if (d.freezeEvery > 0) {
          u.special += dt;
          if (u.special >= d.freezeEvery) {
            u.special = 0;
            _tideFreeze(p, d);
          }
        }
        u.cd -= dt * (1 + sb) * slowCell;
        if (u.cd > 0) continue;
        // The Wrecker's false lantern soaks single-target shots.
        if (single &&
            lanternT > 0 &&
            lanternHits > 0 &&
            lanternPos.dist(pos) <= range) {
          u.cd += d.interval;
          lanternHits--;
          fx.add(
            Fx(
              FxType.shot,
              x: pos.x,
              y: pos.y,
              x2: lanternPos.x,
              y2: lanternPos.y,
              color: d.color,
            ),
          );
          if (lanternHits <= 0) {
            lanternT = 0;
            fx.add(
              Fx(
                FxType.text,
                x: lanternPos.x,
                y: lanternPos.y,
                text: 'LANTERN OUT',
                color: 0xFFFFC300,
              ),
            );
          }
          continue;
        }
        final targets = _targets(
          pos,
          range,
          d.pulse ? 999 : d.multi,
          by: d,
          side: p,
        );
        if (targets.isEmpty) {
          u.cd = 0;
          continue;
        }
        u.cd += d.interval;
        u.attacks++;
        _attack(p, u, d, pos, targets, unions, birds, ci);
      }
    }
  }

  List<Enemy> _targets(
    V2 pos,
    double range,
    int n, {
    UnitDef? by,
    PlayerSide? side,
  }) {
    final inRange = <Enemy>[];
    for (final e in enemies) {
      if (e.dead || e.submerged || e.s < 0) continue;
      if (!_canTarget(e, by, side, pos)) continue;
      if (field.at(e).dist(pos) <= range) inRange.add(e);
    }
    // Lampjaw's lure: within 2 cells it must be shot first.
    int lured(Enemy e) =>
        (e.trait == Trait.lure && field.at(e).dist(pos) <= 2.0) ? 1 : 0;
    inRange.sort((a, b) {
      final l = lured(b) - lured(a);
      return l != 0 ? l : b.traveled.compareTo(a.traveled);
    });
    if (inRange.length <= n) return inRange;
    return inRange.sublist(0, n);
  }

  void _attack(
    PlayerSide p,
    UnitInst u,
    UnitDef d,
    V2 pos,
    List<Enemy> targets,
    Set<String> unions,
    int birds, [
    int ci = -1,
  ]) {
    final mainKind = (d.multi <= 1 && d.splash <= 0 && !d.pulse && d.chain == 0)
        ? kHitSingle
        : kHitArea;
    var dmg = d.dmg * dmgMult(p, d);
    final bond = bondAt(p, ci);
    if (bond != null) dmg *= 1 + bond.dmg;
    if (unions.contains('Staff') && d.tags.contains('Staff')) dmg *= 1.2;
    if (d.perBird > 0) dmg *= 1 + d.perBird * birds;
    if (d.pennyScale > 0) {
      dmg += d.pennyScale * math.min(p.pennies, 1500) * dmgMult(p, d);
    }
    final sweets = unions.contains('Sweets') && d.tags.contains('Sweets');

    if (d.jackpotEvery > 0 && u.attacks % d.jackpotEvery == 0) {
      for (final e in _targets(pos, d.range + 1, 999, by: d, side: p)) {
        _damage(e, dmg * 10, p, unit: d, kind: kHitArea);
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
        final lp = field.at(last);
        for (final e in enemies) {
          if (e.dead || e.submerged || hitList.contains(e)) continue;
          if (!_canTarget(e, d, p, pos)) continue;
          final dd = field.at(e).dist(lp);
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
      final tp = field.at(t);
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
      var hit = dmg * _hitMult(p, ci, d, t);
      if (t.isBoss) hit *= d.bossMult * (1 + (bond?.boss ?? 0));
      var crit = false;
      if (d.critChance > 0 && rng.nextDouble() < d.critChance) {
        hit *= d.critMult;
        crit = true;
      } else if (bond != null &&
          bond.crit > 0 &&
          rng.nextDouble() < bond.crit) {
        hit *= 2;
        crit = true;
      }
      final landed = _damage(t, hit, p, unit: d, crit: crit, kind: mainKind);
      if (!landed) continue;
      _onHit(p, u, d, t);
      if (d.splash > 0) {
        for (final o in [...enemies]) {
          if (o == t || o.dead || o.submerged) continue;
          if (field.at(o).dist(tp) <= d.splash) {
            _damage(
              o,
              hit * 0.6,
              p,
              unit: d,
              canEvade: false,
              quiet: true,
              kind: kHitArea,
            );
          }
          if (d.burnDps > 0 && !o.dead && field.at(o).dist(tp) <= d.splash) {
            _burn(o, p, d);
          }
          if (d.slowPct > 0 && !o.dead && field.at(o).dist(tp) <= d.splash) {
            _slow(o, d, sweets);
          }
        }
      }
      if (t.dead) continue;
      if (d.slowPct > 0) _slow(t, d, sweets);
      if (d.burnDps > 0) _burn(t, p, d);
      if (d.cursePct > 0 && !_statusImmune(t)) {
        t.cursePct = math.max(t.cursePct, d.cursePct);
        t.curseT = d.curseDur;
        if (t.trait == Trait.tin && t.tin) {
          // Out of the tin: no armour, double speed.
          t.tin = false;
          t.speed *= 2;
          fx.add(
            Fx(
              FxType.text,
              x: tp.x,
              y: tp.y,
              text: 'TIN CRACKED',
              color: 0xFFB8B8B8,
            ),
          );
        }
      }
      if (d.stunChance > 0 && rng.nextDouble() < d.stunChance) {
        if (t.boss?.mech != BossMech.inspector && !_controlBlocked(t)) {
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
          kind: kHitStatus,
        );
      }
    }
  }

  void _slow(Enemy e, UnitDef d, bool sweets) {
    if (e.boss?.mech == BossMech.inspector) return;
    // Chip Darts fly over slows.
    if (e.trait == Trait.flying) return;
    if (_controlBlocked(e)) return;
    var pct = d.slowPct * (sweets ? 1.5 : 1);
    var dur = d.slowDur * (sweets ? 1.5 : 1);
    if (e.isBoss) pct *= 0.5;
    e.slowPct = math.min(0.7, math.max(e.slowPct, pct));
    e.slowT = math.max(e.slowT, dur);
  }

  void _burn(Enemy e, PlayerSide p, UnitDef d) {
    if (_statusImmune(e)) return;
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
      if (!_controlBlocked(e)) e.freezeT = math.max(e.freezeT, dur);
      _damage(
        e,
        d.freezeDmg * dmgMult(p, d),
        p,
        unit: d,
        canEvade: false,
        quiet: true,
        kind: kHitArea,
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
    int kind = kHitSingle,
    bool shared = false,
  }) {
    if (e.dead || e.submerged) return false;
    // Only the rear carriage of the Ghost Train can be hit.
    if (e.boss?.mech == BossMech.ghosttrain && e.carriages > 0) return false;
    if (e.trainOf != null && !e.trainOf!.dead) {
      final rear = enemies
          .where((c) => !c.dead && c.trainOf == e.trainOf)
          .fold<Enemy?>(
            null,
            (a, c) => a == null || c.traveled < a.traveled ? c : a,
          );
      if (rear != e) return false;
    }
    if (canEvade) {
      // The Ringmaster's knife thrower: the next few shots go wide.
      var miss = false;
      if (e.knifeMiss > 0) {
        e.knifeMiss--;
        miss = true;
      } else {
        var ev = _dodge(e, unit);
        if (e.cloudT > 0) ev += 0.25;
        miss = ev > 0 && rng.nextDouble() < ev.clamp(0.0, 0.85);
      }
      if (miss) {
        if (!quiet) {
          final p = field.at(e);
          fx.add(Fx(FxType.miss, x: p.x, y: p.y));
        }
        return false;
      }
    }
    // Razor Clam: the shell takes whole hits.
    if (e.shellHits > 0 && kind != kHitStatus) {
      e.shellHits--;
      if (!quiet) {
        final p = field.at(e);
        fx.add(
          Fx(
            FxType.text,
            x: p.x,
            y: p.y,
            text: 'SHELL ${e.shellHits}',
            color: 0xFFE9C46A,
            size: 0.7,
          ),
        );
      }
      return true;
    }
    var a = amount;
    if (e.curseT > 0) {
      a *= 1 + e.cursePct;
    } else if (!ignoreArmor) {
      a *= 1 - (e.bareT > 0 ? 0 : _armorOf(e));
    }
    // The Shadow Keeper adapts to what hurts most.
    if (e.boss?.mech == BossMech.shadowkeeper) {
      e.hurtBy[kind] += a;
      if (e.resist == kind) a *= 0.5;
    }
    // The Hollow shares every hit with things within 2 cells.
    if (!shared && e.trait == Trait.hollow) {
      final hp = field.at(e);
      final group = [
        for (final o in enemies)
          if (o != e && !o.dead && !o.isBoss && field.at(o).dist(hp) <= 2.0) o,
      ];
      if (group.isNotEmpty) {
        final part = a / (group.length + 1);
        for (final o in group) {
          _damage(
            o,
            part,
            src,
            unit: unit,
            canEvade: false,
            ignoreArmor: true,
            quiet: true,
            kind: kind,
            shared: true,
          );
        }
        a = part;
      }
    }
    if (e.shield > 0) {
      final ab = math.min(e.shield, a);
      e.shield -= ab;
      a -= ab;
    }
    // Glass Grub and the Glass Colossus: no hit takes more than a slice.
    if (e.trait == Trait.cap) a = math.min(a, e.maxHp * e.def!.pow);
    if (e.boss?.mech == BossMech.colossus) a = math.min(a, e.maxHp * 0.03);
    e.hp -= a;
    e.lastKind = kind;
    if (!quiet) {
      e.hitFlash = 0.1;
      if (crit || (e.isBoss && rng.nextDouble() < 0.15)) {
        final p = field.at(e);
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
    // Twice-Drowned: back up once, unless area damage finished it.
    if (e.hp <= 0 &&
        e.trait == Trait.revive &&
        !e.shellUsed &&
        kind != kHitArea) {
      e.shellUsed = true;
      e.hp = e.maxHp * e.def!.pow;
      e.stunT = math.max(e.stunT, 0.8);
      final at = field.at(e);
      fx.add(Fx(FxType.text, x: at.x, y: at.y, text: 'BACK UP', color: e.def!.color));
      return false;
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
    final pos = field.at(e);
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
      if (unit != null) {
        final chance = bondPennyFor(src, unit);
        if (chance > 0 && rng.nextDouble() < chance) {
          src.pennies++;
          src.stats.pennyEarned++;
        }
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
    _onDeath(e, unit, e.lastKind);
    if (e.def?.id == 'pollock' && e.traveled < field.cycle) {
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
        _spawn(sp, route: e.route, s: e.s - 0.25 * i, traveled: e.traveled);
      }
    }
    if (e.isBoss) _bossDown(e);
  }

  void _bossDown(Enemy e) {
    // The engine takes its carriages with it.
    for (final c in enemies) {
      if (c.trainOf == e && !c.dead) c.dead = true;
    }
    final alive = bossesAlive;
    // The other twin takes over the board-wide moves.
    if (e.twinLead) {
      for (final b in alive) {
        if (b.boss == e.boss && !b.twinLead) {
          b.twinLead = true;
          b.phase = math.max(b.phase, e.phase);
          break;
        }
      }
    }
    final pos = field.at(e);
    if (alive.isNotEmpty) {
      if (!alive.any((b) => b.boss == e.boss)) {
        bossesKilled++;
        say(e.name, e.boss!.defeat);
      } else {
        tell(
          'One ${e.name} down. One to go.',
          x: pos.x,
          y: pos.y,
          r: 1,
          dur: 2,
          color: e.boss!.color,
        );
      }
      fx.add(Fx(FxType.shake, size: 0.8));
      return;
    }
    bossesKilled++;
    say(e.name, e.boss!.defeat);
    fx.add(Fx(FxType.shake, size: 1.2));
    payQuickKill();
    bossList.clear();
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
