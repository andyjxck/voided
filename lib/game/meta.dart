// Pier Pressure — meta-progression: sea glass, Back Room upgrades, the Jobs
// Board, the figurine album, difficulty unlocks, settings and the save file.
//
// Pure Dart (no Flutter), so tests and tools can use it headless. The UI keeps
// one MetaSave alive, mutates it, and calls the save callback after changes.

import 'dart:convert';

import 'data.dart';
import 'sim.dart';

// ---------------------------------------------------------------------------
// Back Room upgrades (permanent, bought with sea glass)
// ---------------------------------------------------------------------------

class MetaUpgrade {
  final String id;
  final String name;
  final String desc;
  final int max;
  final int baseCost;
  final int costStep;
  const MetaUpgrade(this.id, this.name, this.desc, {required this.max, required this.baseCost, required this.costStep});

  /// Price of the next level when you already own [level].
  int cost(int level) => baseCost + costStep * level;
}

/// Per-level effect sizes. Tune here.
const int kFloatPerLevel = 15; // starting pennies
const int kCloverPerLevel = 1; // starting leaves
const int kBentCoinPerLevel = 1; // summon discount in pennies
const int kElbowGreasePct = 4; // +damage % on your side
const double kElbowGreasePerLevel = kElbowGreasePct / 100;

const List<MetaUpgrade> kMetaUpgrades = [
  MetaUpgrade(
    'float',
    'Float in the Till',
    '+$kFloatPerLevel starting pennies a level. Nobody counts it.',
    max: 5,
    baseCost: 20,
    costStep: 15,
  ),
  MetaUpgrade(
    'clover',
    'Pressed Clover',
    '+$kCloverPerLevel starting leaf a level. Found in a lost-property sandwich.',
    max: 3,
    baseCost: 40,
    costStep: 30,
  ),
  MetaUpgrade(
    'bentcoin',
    'Bent Coin',
    'Summons cost $kBentCoinPerLevel penny less a level. The machine has stopped noticing.',
    max: 5,
    baseCost: 30,
    costStep: 20,
  ),
  MetaUpgrade(
    'grease',
    'Elbow Grease',
    '+$kElbowGreasePct% damage on your board a level. Mostly grease.',
    max: 5,
    baseCost: 35,
    costStep: 25,
  ),
];

final Map<String, MetaUpgrade> kMetaUpgradeById = {for (final u in kMetaUpgrades) u.id: u};

// ---------------------------------------------------------------------------
// Jobs Board (one-off missions, checked at the end of each run)
// ---------------------------------------------------------------------------

class Mission {
  final String id;
  final String name;
  final String desc;
  final int reward;
  final bool Function(Game g) check;
  const Mission(this.id, this.name, this.desc, this.reward, this.check);
}

final List<Mission> kMissions = [
  Mission('first_boss', 'Pest Control', 'Beat your first boss.', 15, (g) => g.bossesKilled >= 1),
  Mission('wave20', 'Halfway Down the Pier', 'Reach wave 20.', 20, (g) => g.wave >= 20),
  Mission(
    'win',
    'Last Night of the Season',
    'Survive wave $kFinalWave and see off the final boss.',
    50,
    (g) => g.status == GameStatus.won || (g.endless && g.wave > kFinalWave),
  ),
  Mission(
    'solo_win',
    'Skeleton Staff',
    'Win a Solo run.',
    40,
    (g) => g.cfg.mode == GameMode.solo && (g.status == GameStatus.won || g.endless),
  ),
  Mission(
    'coop_win',
    'Brenda\'s Favourite',
    'Win a Co-op run with $kPartnerName.',
    40,
    (g) => g.cfg.mode == GameMode.coop && (g.status == GameStatus.won || g.endless),
  ),
  Mission(
    'storm_win',
    'Council Can Do One',
    'Win on ${Difficulty.storm.label}.',
    80,
    (g) => g.cfg.difficulty == Difficulty.storm && (g.status == GameStatus.won || g.endless),
  ),
  Mission('mythic', 'Something in the Back', 'Craft a Mythic figurine.', 25, (g) => g.you.stats.mythics >= 1),
  Mission('merges', 'Three Into One', 'Merge 15 times in one run.', 15, (g) => g.you.stats.merges >= 15),
  Mission('gamble', 'Feeling Lucky', 'Win 3 gambles in one run.', 20, (g) => g.you.stats.gambleWins >= 3),
  Mission('kills', 'Seafood Platter', 'Your board takes out 1,000 sea things in one run.', 25, (g) => g.you.stats.kills >= 1000),
  Mission('endless', 'Off Season', 'Reach wave ${kFinalWave + 10} in Endless.', 40, (g) => g.endless && g.wave >= kFinalWave + 10),
];

final Map<String, Mission> kMissionById = {for (final m in kMissions) m.id: m};

// ---------------------------------------------------------------------------
// Run rewards
// ---------------------------------------------------------------------------

/// Sea glass per wave reached, per boss beaten, and for a win. Scaled by
/// [kDifficultyGlassMult].
const int kGlassPerWave = 1;
const int kGlassPerBoss = 5;
const int kGlassForWin = 25;
const List<double> kDifficultyGlassMult = [1.0, 1.5, 2.0];

class RunSummary {
  /// Sea glass from this run (missions included).
  final int seaGlass;
  final bool newBest;
  final List<Mission> newMissions;

  /// Headline lines for the end screen, e.g. difficulty unlocks.
  final List<String> unlocks;
  const RunSummary({required this.seaGlass, required this.newBest, required this.newMissions, required this.unlocks});
}

// ---------------------------------------------------------------------------
// The save
// ---------------------------------------------------------------------------

class MetaSave {
  static const int version = 1;

  int seaGlass = 0;
  final Map<String, int> upgrades = {};
  final Set<String> missions = {};
  final Set<String> discovered = {};

  /// Best wave per `mode-difficulty` key, e.g. 'coop-calm'.
  final Map<String, int> best = {};

  /// Highest unlocked Difficulty index.
  int maxDifficulty = 0;
  int runs = 0;
  int wins = 0;
  bool tutorialDone = false;
  bool sound = true;
  bool music = true;
  bool shake = true;

  // What has already been paid out for the current game, so an Endless
  // continuation that ends later only pays the difference.
  Game? _paidGame;
  int _paidWave = 0;
  int _paidBosses = 0;
  bool _paidWin = false;

  MetaSave();

  int level(String id) => (upgrades[id] ?? 0).clamp(0, kMetaUpgradeById[id]?.max ?? 0);

  /// Spend sea glass on the next level. False if maxed or too poor.
  bool buy(MetaUpgrade u) {
    final l = level(u.id);
    if (l >= u.max) return false;
    final c = u.cost(l);
    if (seaGlass < c) return false;
    seaGlass -= c;
    upgrades[u.id] = l + 1;
    return true;
  }

  /// Game settings for a new run, with the Back Room upgrades applied.
  GameConfig configFor(GameMode mode, Difficulty difficulty, int seed) => GameConfig(
    mode: mode,
    difficulty: difficulty,
    seed: seed,
    bonusPennies: kFloatPerLevel * level('float'),
    bonusLeaves: kCloverPerLevel * level('clover'),
    summonDiscount: kBentCoinPerLevel * level('bentcoin'),
    dmgBonus: kElbowGreasePerLevel * level('grease'),
  );

  /// Record a finished run (won, lost, or an Endless run that ended) and pay
  /// out. Safe to call again for the same game after Endless: it only pays
  /// for progress since the last call and counts the run once.
  RunSummary finishRun(Game g) {
    final fresh = !identical(g, _paidGame);
    if (fresh) {
      _paidGame = g;
      _paidWave = 0;
      _paidBosses = 0;
      _paidWin = false;
      runs++;
    }
    final won = g.status == GameStatus.won || g.endless;
    final mult = kDifficultyGlassMult[g.cfg.difficulty.index];
    var base = kGlassPerWave * (g.wave - _paidWave).clamp(0, 1 << 20) + kGlassPerBoss * (g.bossesKilled - _paidBosses).clamp(0, 1 << 20);
    if (won && !_paidWin) {
      base += kGlassForWin;
      wins++;
    }
    _paidWave = g.wave > _paidWave ? g.wave : _paidWave;
    _paidBosses = g.bossesKilled > _paidBosses ? g.bossesKilled : _paidBosses;
    var glass = (base * mult).round();

    final unlocks = <String>[];
    if (won && !_paidWin) {
      final next = g.cfg.difficulty.index + 1;
      if (next < Difficulty.values.length && next > maxDifficulty) {
        maxDifficulty = next;
        unlocks.add('Unlocked: ${Difficulty.values[next].label}');
      }
    }
    if (won) _paidWin = true;

    final key = '${g.cfg.mode.name}-${g.cfg.difficulty.name}';
    final newBest = g.wave > (best[key] ?? 0);
    if (newBest) best[key] = g.wave;

    final newFigs = g.you.seen.difference(discovered);
    if (newFigs.isNotEmpty) {
      discovered.addAll(newFigs);
      unlocks.add(
        newFigs.length == 1
            ? 'New in the album: ${kUnitById[newFigs.first]?.name ?? newFigs.first}'
            : '${newFigs.length} new figurines in the album',
      );
    }

    final done = <Mission>[];
    for (final m in kMissions) {
      if (!missions.contains(m.id) && m.check(g)) {
        missions.add(m.id);
        done.add(m);
        glass += m.reward;
      }
    }

    seaGlass += glass;
    return RunSummary(seaGlass: glass, newBest: newBest, newMissions: done, unlocks: unlocks);
  }

  // ---------------- persistence ----------------

  Map<String, dynamic> toJson() => {
    'v': version,
    'seaGlass': seaGlass,
    'upgrades': upgrades,
    'missions': missions.toList()..sort(),
    'discovered': discovered.toList()..sort(),
    'best': best,
    'maxDifficulty': maxDifficulty,
    'runs': runs,
    'wins': wins,
    'tutorialDone': tutorialDone,
    'sound': sound,
    'music': music,
    'shake': shake,
  };

  String encode() => jsonEncode(toJson());

  /// Never throws: a missing or corrupt save gives a fresh one, and unknown
  /// upgrade, mission and figurine ids are dropped.
  static MetaSave decode(String? raw) {
    final m = MetaSave();
    if (raw == null || raw.isEmpty) return m;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return m;
      int i(Object? v, int d) => v is num ? v.toInt() : d;
      bool b(Object? v, bool d) => v is bool ? v : d;
      m.seaGlass = i(j['seaGlass'], 0).clamp(0, 1 << 30);
      final up = j['upgrades'];
      if (up is Map) {
        up.forEach((k, v) {
          final def = kMetaUpgradeById[k];
          if (def != null) m.upgrades[k as String] = i(v, 0).clamp(0, def.max);
        });
      }
      final ms = j['missions'];
      if (ms is List) m.missions.addAll(ms.whereType<String>().where(kMissionById.containsKey));
      final ds = j['discovered'];
      if (ds is List) m.discovered.addAll(ds.whereType<String>().where(kUnitById.containsKey));
      final bs = j['best'];
      if (bs is Map) {
        bs.forEach((k, v) {
          if (k is String && v is num) m.best[k] = v.toInt();
        });
      }
      m.maxDifficulty = i(j['maxDifficulty'], 0).clamp(0, Difficulty.values.length - 1);
      m.runs = i(j['runs'], 0);
      m.wins = i(j['wins'], 0);
      m.tutorialDone = b(j['tutorialDone'], false);
      m.sound = b(j['sound'], true);
      m.music = b(j['music'], true);
      m.shake = b(j['shake'], true);
    } catch (_) {
      return MetaSave();
    }
    return m;
  }
}
