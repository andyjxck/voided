part of 'data.dart';

// ---------------- Bonds and house rules ----------------
//
// Bonds: two particular figurines that fight better side by side. Put them in
// touching cells (diagonals count) and both cells get the bond's bonus.
// House rules: small economy rules, each explained in one line in game.

class BondDef {
  final String a;
  final String b;
  final String name;

  /// Bonus to both cells: damage, attack speed, range (cells), extra chance
  /// to crit for double damage, damage against bosses, and the chance that
  /// a kill by either drops a penny.
  final double dmg, spd, range, crit, boss, penny;
  const BondDef(
    this.a,
    this.b,
    this.name, {
    this.dmg = 0,
    this.spd = 0,
    this.range = 0,
    this.crit = 0,
    this.boss = 0,
    this.penny = 0,
  });

  bool has(String id) => id == a || id == b;
  String other(String id) => id == a ? b : a;

  /// One short line, e.g. 'both attack 20% faster'.
  String get effect {
    final parts = <String>[
      if (spd > 0) 'attack ${(spd * 100).round()}% faster',
      if (dmg > 0) 'hit ${(dmg * 100).round()}% harder',
      if (range > 0) 'reach ${_num(range)} cells further',
      if (crit > 0) 'get a ${(crit * 100).round()}% chance to hit double',
      if (boss > 0) 'deal ${(boss * 100).round()}% more to bosses',
      if (penny > 0) 'drop a penny on ${(penny * 100).round()}% of kills',
    ];
    if (parts.length <= 1) return 'both ${parts.join()}';
    return 'both ${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Bonds pay off when the two sit in touching cells. Commons and Rares have
/// some so a bond can turn up early; the rest reward planning a board.
const List<BondDef> kBonds = [
  // Early pairs.
  BondDef('gull', 'rock', 'Chip Shop', dmg: 0.15),
  BondDef('dave', 'carl', 'Odd Jobs', spd: 0.1, penny: 0.15),
  BondDef('lil', 'dave', 'Late Shift', range: 0.5),
  BondDef('gull', 'admiral', 'Flight Line', spd: 0.2),
  BondDef('dave', 'lou', 'Night Watch', dmg: 0.2),
  BondDef('rock', 'floss', 'Sugar Rush', spd: 0.15),
  BondDef('carl', 'thwack', 'Shove and Crack', penny: 0.25),
  BondDef('mouse', 'floss', 'Sweet Tooth', crit: 0.12),
  // Mid pairs, often across unions.
  BondDef('lil', 'lamplighter', 'Wick and Flame', range: 0.6),
  BondDef('sal', 'lil', 'Firelight', dmg: 0.15, crit: 0.1),
  BondDef('bandsman', 'lou', 'Marching Order', spd: 0.2),
  BondDef('tess', 'mouse', 'Sugar and Steel', dmg: 0.2),
  BondDef('morag', 'hale', 'Old Salts', boss: 0.25),
  BondDef('squall', 'admiral', 'Stormfront', range: 0.5, spd: 0.1),
  BondDef('claw', 'carl', 'Rigged Machine', penny: 0.2, dmg: 0.1),
  // Late pairs.
  BondDef('keeper', 'diver', 'Deep Watch', dmg: 0.15, range: 0.4),
  BondDef('vex', 'bertie', 'House Edge', penny: 0.3, crit: 0.1),
  BondDef('watchman', 'bandsman', 'On Patrol', spd: 0.25),
  BondDef('icecream', 'tess', 'Brain Freeze', boss: 0.3),
  BondDef('elmo', 'lamplighter', 'Bonfire Night', dmg: 0.25),
  BondDef('albatross', 'squall', 'Eye of the Storm', crit: 0.15, spd: 0.1),
];

/// Every bond [id] can be part of.
List<BondDef> bondsOf(String id) => [
  for (final b in kBonds)
    if (b.has(id)) b,
];

/// True when board cells [i] and [j] touch, diagonals included.
bool cellsTouch(int i, int j) {
  if (i == j) return false;
  final dc = (i % kBoardCols - j % kBoardCols).abs();
  final dr = (i ~/ kBoardCols - j ~/ kBoardCols).abs();
  return dc <= 1 && dr <= 1;
}

// ---- House rules ----

/// Hoard: each full [kHoardStep] pennies you hold adds [kHoardPct] damage,
/// up to [kHoardTiers] steps.
const int kHoardStep = 100;
const double kHoardPct = 0.02;
const int kHoardTiers = 5;

/// Interest: at each wave start, 1 penny for every [kInterestPer] held, up
/// to [kInterestMax].
const int kInterestPer = 40;
const int kInterestMax = 6;

/// Full stack: three of a kind in one cell attack this much faster.
const double kFullStackSpeed = 0.12;

/// Clean sweep: start a wave with at most this many riftlings out and every
/// side earns [kCleanSweepPay].
const int kCleanSweepMax = 6;
const int kCleanSweepPay = 4;

/// Quick kill: clear a boss wave with at least this share of the timer left
/// and every side earns [kQuickKillPay].
const double kQuickKillShare = 0.5;
const int kQuickKillPay = 15;

class HouseRule {
  final String name;
  final String line;
  const HouseRule(this.name, this.line);
}

/// The house rules, one line each, in the order the game shows them.
const List<HouseRule> kHouseRules = [
  HouseRule(
    'Hoard',
    'Every $kHoardStep pennies you hold add 2% damage, up to 10%.',
  ),
  HouseRule(
    'Interest',
    'Each wave pays 1 extra penny for every $kInterestPer you hold, up to $kInterestMax.',
  ),
  HouseRule(
    'Full stack',
    'Three of a kind in one cell attack 12% faster, until you merge them.',
  ),
  HouseRule(
    'Bonds',
    'Some pairs fight better in touching cells. Look for the gold link.',
  ),
  HouseRule(
    'Clean sweep',
    'Start a wave with $kCleanSweepMax or fewer riftlings out for $kCleanSweepPay pennies.',
  ),
  HouseRule(
    'Quick kill',
    'Clear a boss wave with half its timer left for $kQuickKillPay pennies.',
  ),
];

/// Hoard steps for [pennies] held, 0 to [kHoardTiers].
int hoardTier(int pennies) => (pennies ~/ kHoardStep).clamp(0, kHoardTiers);

/// Interest paid at a wave start for [pennies] held.
int interestFor(int pennies) =>
    (pennies ~/ kInterestPer).clamp(0, kInterestMax);
