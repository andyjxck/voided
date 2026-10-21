// Voided — meta-progression: sea glass, Back Room upgrades, the Jobs Board,
// the figurine album, levels, settings and the save file.
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
  const MetaUpgrade(
    this.id,
    this.name,
    this.desc, {
    required this.max,
    required this.baseCost,
    required this.costStep,
  });

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

final Map<String, MetaUpgrade> kMetaUpgradeById = {
  for (final u in kMetaUpgrades) u.id: u,
};

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

bool _won(Game g) =>
    g.status == GameStatus.won || (g.endless && g.wave > kFinalWave);

final List<Mission> kMissions = [
  Mission(
    'boss1',
    'Pest Control',
    'Beat your first boss.',
    10,
    (g) => g.bossesKilled >= 1,
  ),
  Mission(
    'wave25',
    'Halfway Down the Pier',
    'Reach wave 25.',
    15,
    (g) => g.wave >= 25,
  ),
  Mission(
    'boss4',
    'Regular Customers',
    'Beat 4 bosses in one run.',
    25,
    (g) => g.bossesKilled >= 4,
  ),
  Mission(
    'level1',
    'Last Night of the Season',
    'Clear Level 1: beat the Landlord on wave $kFinalWave.',
    50,
    (g) => g.cfg.level >= 1 && _won(g),
  ),
  Mission(
    'solo_win',
    'Skeleton Staff',
    'Clear any level in Solo.',
    40,
    (g) => g.cfg.mode == GameMode.solo && _won(g),
  ),
  Mission(
    'coop_win',
    'Brenda\'s Favourite',
    'Clear any level with $kPartnerName.',
    30,
    (g) => g.cfg.mode == GameMode.coop && _won(g),
  ),
  Mission(
    'level2',
    'Fog Lifted',
    'Clear Level 2, Fogbank Arcade.',
    80,
    (g) => g.cfg.level >= 2 && _won(g),
  ),
  Mission(
    'level3',
    'Off With His Claws',
    'Clear Level 3, Crab Cove.',
    120,
    (g) => g.cfg.level >= 3 && _won(g),
  ),
  Mission(
    'level4',
    'Staring Back',
    'Clear Level 4, the Void Pier.',
    200,
    (g) => g.cfg.level >= 4 && _won(g),
  ),
  Mission(
    'mythic',
    'Something in the Back',
    'Craft a Mythic figurine.',
    25,
    (g) => g.you.stats.mythics >= 1,
  ),
  Mission(
    'mythic3',
    'Full Back Room',
    'Craft 3 Mythics in one run.',
    70,
    (g) => g.you.stats.mythics >= 3,
  ),
  Mission(
    'merges40',
    'Three Into One',
    'Merge 40 times in one run.',
    25,
    (g) => g.you.stats.merges >= 40,
  ),
  Mission(
    'merges80',
    'Compactor',
    'Merge 80 times in one run.',
    50,
    (g) => g.you.stats.merges >= 80,
  ),
  Mission(
    'gamble6',
    'Feeling Lucky',
    'Win 6 gambles in one run.',
    30,
    (g) => g.you.stats.gambleWins >= 6,
  ),
  Mission(
    'summon150',
    'Machine Feeder',
    'Summon 150 times in one run.',
    30,
    (g) => g.you.stats.summons >= 150,
  ),
  Mission(
    'kills3k',
    'Seafood Platter',
    'Your board takes out 3,000 sea things in one run.',
    35,
    (g) => g.you.stats.kills >= 3000,
  ),
  Mission(
    'kills6k',
    'All You Can Eat',
    'Your board takes out 6,000 sea things in one run.',
    60,
    (g) => g.you.stats.kills >= 6000,
  ),
  Mission(
    'upgrade20',
    'Elbow Deep',
    'Buy 20 Elbow Grease upgrades in one run.',
    30,
    (g) => g.you.stats.upgrades >= 20,
  ),
  Mission(
    'rich',
    'Coin Pusher',
    'Earn 6,000 pennies in one run.',
    35,
    (g) => g.you.stats.pennyEarned >= 6000,
  ),
  Mission(
    'tidy',
    'Tidy Pier',
    'Clear a level without the lane going over 40.',
    90,
    (g) => _won(g) && g.peakLane <= 40,
  ),
  Mission(
    'endless60',
    'Off Season',
    'Reach wave ${kFinalWave + 10} in Endless.',
    50,
    (g) => g.endless && g.wave >= kFinalWave + 10,
  ),
  Mission(
    'endless75',
    'Nobody Goes Home',
    'Reach wave ${kFinalWave + 25} in Endless.',
    100,
    (g) => g.endless && g.wave >= kFinalWave + 25,
  ),
];

final Map<String, Mission> kMissionById = {for (final m in kMissions) m.id: m};

// ---------------------------------------------------------------------------
// Run rewards
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Figurine album: collect copies across runs to fill a page
// ---------------------------------------------------------------------------

/// Copies of a figurine needed to fill its album page, by tier.
int albumNeed(Tier t) => const [60, 30, 12, 4, 1][t.index];

/// Sea glass for filling an album page, by tier.
int albumReward(Tier t) => const [5, 8, 12, 20, 30][t.index];

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
  const RunSummary({
    required this.seaGlass,
    required this.newBest,
    required this.newMissions,
    required this.unlocks,
  });
}

// ---------------------------------------------------------------------------
// The save
// ---------------------------------------------------------------------------

class MetaSave {
  static const int version = 2;

  int seaGlass = 0;
  final Map<String, int> upgrades = {};
  final Set<String> missions = {};

  /// Figurines you have ever had on your board (shown in the album).
  final Set<String> discovered = {};

  /// Copies of each figurine you have had, over every run.
  final Map<String, int> copies = {};

  /// The highest level unlocked, from 1. Play starts here.
  int levelReached = 1;

  /// Best wave per `mode-difficulty` key, e.g. 'coop-calm'.
  final Map<String, int> best = {};

  /// Highest unlocked Difficulty index.
  int maxDifficulty = 0;

  /// The mode and sea state you last picked, so PLAY starts the same way.
  GameMode lastMode = GameMode.coop;
  int lastDifficulty = 0;

  /// Sea state for the next run: the last one picked, if still unlocked.
  Difficulty get nextDifficulty =>
      Difficulty.values[lastDifficulty.clamp(0, maxDifficulty)];
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
  Map<String, int> _paidCopies = {};

  MetaSave();

  int level(String id) =>
      (upgrades[id] ?? 0).clamp(0, kMetaUpgradeById[id]?.max ?? 0);

  /// Copies held toward [d]'s album page, capped at what the page needs.
  int copiesOf(UnitDef d) => (copies[d.id] ?? 0).clamp(0, albumNeed(d.tier));

  /// True once [d]'s album page is full.
  bool collected(UnitDef d) => (copies[d.id] ?? 0) >= albumNeed(d.tier);

  int get collectedCount => kUnits.where(collected).length;

  /// Best wave reached on [lvl] in either mode.
  int bestOnLevel(int lvl) {
    var b = 0;
    for (final m in GameMode.values) {
      final v = best['${m.name}-L$lvl'] ?? 0;
      if (v > b) b = v;
    }
    return b;
  }

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
  GameConfig configFor(
    GameMode mode,
    Difficulty difficulty,
    int seed, {
    int lvl = 1,
  }) => GameConfig(
    mode: mode,
    level: lvl,
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
    var base =
        kGlassPerWave * (g.wave - _paidWave).clamp(0, 1 << 20) +
        kGlassPerBoss * (g.bossesKilled - _paidBosses).clamp(0, 1 << 20);
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
      }
      if (g.cfg.level >= levelReached) {
        levelReached = g.cfg.level + 1;
        unlocks.add(
          'Level $levelReached unlocked: ${levelDef(levelReached).name}',
        );
      }
    }
    if (won) _paidWin = true;

    final key = '${g.cfg.mode.name}-L${g.cfg.level}';
    final newBest = g.wave > (best[key] ?? 0);
    if (newBest) best[key] = g.wave;

    discovered.addAll(g.you.seen);
    // Album copies: only what is new since the last payout for this game.
    final paid = fresh ? <String, int>{} : _paidCopies;
    var pages = 0;
    g.you.got.forEach((id, n) {
      final d = kUnitById[id];
      final add = n - (paid[id] ?? 0);
      if (d == null || add <= 0) return;
      final was = collected(d);
      copies[id] = (copies[id] ?? 0) + add;
      if (!was && collected(d)) {
        pages++;
        glass += albumReward(d.tier);
        unlocks.add('Album page filled: ${d.name}');
      }
    });
    _paidCopies = Map.of(g.you.got);
    if (pages > 3) {
      unlocks.removeWhere((u) => u.startsWith('Album page filled'));
      unlocks.add('$pages album pages filled');
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
    return RunSummary(
      seaGlass: glass,
      newBest: newBest,
      newMissions: done,
      unlocks: unlocks,
    );
  }

  // ---------------- persistence ----------------

  Map<String, dynamic> toJson() => {
    'v': version,
    'seaGlass': seaGlass,
    'upgrades': upgrades,
    'missions': missions.toList()..sort(),
    'discovered': discovered.toList()..sort(),
    'copies': copies,
    'levelReached': levelReached,
    'best': best,
    'maxDifficulty': maxDifficulty,
    'lastMode': lastMode.name,
    'lastDifficulty': lastDifficulty,
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
      if (ms is List) {
        m.missions.addAll(
          ms.whereType<String>().where(kMissionById.containsKey),
        );
      }
      final ds = j['discovered'];
      if (ds is List) {
        m.discovered.addAll(
          ds.whereType<String>().where(kUnitById.containsKey),
        );
      }
      final cp = j['copies'];
      if (cp is Map) {
        cp.forEach((k, v) {
          if (k is String && kUnitById.containsKey(k) && v is num) {
            m.copies[k] = v.toInt().clamp(0, 1 << 20);
          }
        });
      }
      m.levelReached = i(j['levelReached'], 1).clamp(1, 999);
      final bs = j['best'];
      if (bs is Map) {
        bs.forEach((k, v) {
          if (k is String && v is num) m.best[k] = v.toInt();
        });
      }
      m.maxDifficulty = i(
        j['maxDifficulty'],
        0,
      ).clamp(0, Difficulty.values.length - 1);
      m.lastMode = GameMode.values.firstWhere(
        (x) => x.name == j['lastMode'],
        orElse: () => GameMode.coop,
      );
      m.lastDifficulty = i(
        j['lastDifficulty'],
        0,
      ).clamp(0, Difficulty.values.length - 1);
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
