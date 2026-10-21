// Voided — all static game data: figurines, riftlings, bosses, odds,
// economy constants. Everything tunable lives here.

part 'content.dart';
part 'synergy.dart';

/// Enemy health in Solo, as a fraction of Co-op health. One constant, on
/// purpose: tune it here and every enemy, mini-boss and boss follows.
/// Started at 0.65 (the brief). The balance sims (tool/balance.dart,
/// test/balance_test.dart) showed Solo clearly harder than Co-op at 0.65, and
/// closest to Co-op at about 0.5 — see DESIGN.md for the numbers.
const double kSoloHpMultiplier = 0.5;

/// Bosses also take [kSoloHpMultiplier] in Solo, times this. 1.0 means bosses
/// scale exactly like everything else (the sims showed they stay a fight).
final double kSoloBossExtra = double.parse(
  const String.fromEnvironment('SOLOB', defaultValue: '0.7'),
);

/// Share of a wave's threat budget each route gets (its twin gets the
/// same). 0.5 splits the wave exactly in two.
final double kTwinWaveShare = double.parse(
  const String.fromEnvironment('TWINW', defaultValue: '0.5'),
);

// 0.75 and 0.7 (above) bring Calm/Choppy win rates back near the
// pre-content numbers after the content plan's new boss moves (tool/death_probe.dart).
final double kBossHpScale = double.parse(
  const String.fromEnvironment('BOSSHP', defaultValue: '0.75'),
);
final double kSecondFormHp = double.parse(
  const String.fromEnvironment('F2HP', defaultValue: '1.0'),
);

enum GameMode { coop, solo }

enum Tier { common, rare, epic, legendary, mythic }

extension TierInfo on Tier {
  String get label =>
      const ['Common', 'Rare', 'Epic', 'Legendary', 'Mythic'][index];
  int get color =>
      const [0xFFB9C4CC, 0xFF4FC3F7, 0xFFC77DFF, 0xFFFFC94D, 0xFFFF5E7E][index];
}

enum Difficulty { calm, choppy, storm }

extension DifficultyInfo on Difficulty {
  String get label => const ['Hairline', 'Widening', 'Full Breach'][index];
  double get hpMult => const [1.0, 1.45, 1.95][index];
  String get blurb => const [
    'Only a hairline crack so far. Should be quiet.',
    'The tide is in a mood. Enemies have 45% more health.',
    'The Rift is wide open. You are still here. +95% enemy health.',
  ][index];
}

enum Shape { circle, square, diamond, hexagon, star, triangle, drop, shield }

class UnitDef {
  final String id;
  final String name;
  final Tier tier;
  final List<String> tags;
  final int color;
  final Shape shape;
  final String mono;
  final double dmg;
  final double interval;
  final double range;
  final String desc;
  final String quip;

  /// Special move (see [Abil]) and its numbers.
  final Abil abil;
  final double abilEvery;
  final double abilPow;
  final double abilDur;
  final double splash;
  final double slowPct;
  final double slowDur;
  final double stunChance;
  final double stunDur;
  final int chain;
  final int multi;
  final double burnDps;
  final double burnDur;
  final double cursePct;
  final double curseDur;
  final int grabEvery;
  final double critChance;
  final double critMult;
  final bool pulse;
  final double bossMult;
  final int killPennies;
  final double pennyOnHit;
  final String? auraTag; // 'all' or a tag
  final double auraSpeed;
  final double auraRange;
  final double freezeEvery;
  final double freezeDur;
  final double freezeDmg;
  final int jackpotEvery;
  final double executePct;
  final double perBird;
  final double pennyScale;
  const UnitDef({
    required this.id,
    required this.name,
    required this.tier,
    required this.tags,
    required this.color,
    required this.shape,
    required this.mono,
    required this.dmg,
    required this.interval,
    required this.range,
    required this.desc,
    required this.quip,
    this.abil = Abil.none,
    this.abilEvery = 0,
    this.abilPow = 0,
    this.abilDur = 0,
    this.splash = 0,
    this.slowPct = 0,
    this.slowDur = 0,
    this.stunChance = 0,
    this.stunDur = 0,
    this.chain = 0,
    this.multi = 1,
    this.burnDps = 0,
    this.burnDur = 0,
    this.cursePct = 0,
    this.curseDur = 0,
    this.grabEvery = 0,
    this.critChance = 0,
    this.critMult = 1,
    this.pulse = false,
    this.bossMult = 1,
    this.killPennies = 0,
    this.pennyOnHit = 0,
    this.auraTag,
    this.auraSpeed = 0,
    this.auraRange = 0,
    this.freezeEvery = 0,
    this.freezeDur = 0,
    this.freezeDmg = 0,
    this.jackpotEvery = 0,
    this.executePct = 0,
    this.perBird = 0,
    this.pennyScale = 0,
  });

  double get dps => dmg / interval * multi.clamp(1, 99);
}

// Tags (the "unions" of the Riftwardens). Three different figurines of one union on
// your board switches its union rule on.
const Map<String, String> kUnionRules = {
  'Birds': 'Skyborn attack 20% faster',
  'Staff': 'Wardens hit 20% harder',
  'Sweets': 'Alchemists slow 50% harder and longer',
  'Arcade': '+1 penny every 8 kills by Rogues',
  'Sea': 'Tidecallers get +0.6 range',
  'Lamp':
      'Lightbringers show hidden things to everyone, and their hits never miss',
};

/// The name the player sees for each union tag. The tags themselves stay the
/// same in code and saves; only the display name changed (the Riftwardens).
const Map<String, String> kUnionNames = {
  'Birds': 'Skyborn',
  'Staff': 'Wardens',
  'Sweets': 'Alchemists',
  'Arcade': 'Rogues',
  'Sea': 'Tidecallers',
  'Lamp': 'Lightbringers',
};

/// Display name for union [tag].
String unionName(String tag) => kUnionNames[tag] ?? tag;

const List<UnitDef> kUnits = [..._kUnitsBase, ...kUnitsNew];

const List<UnitDef> _kUnitsBase = [
  // ---------------- COMMON ----------------
  UnitDef(
    id: 'gull',
    name: 'Wren, Sparrow Scout',
    tier: Tier.common,
    tags: ['Birds'],
    color: 0xFFE8EEF2,
    shape: Shape.triangle,
    mono: 'Wr',
    dmg: 6,
    interval: 0.6,
    range: 2.6,
    desc:
        'Rapid slingshot shots at one target.',
    quip: 'Scouted the Rift twice. Brought snacks both times.',
  ),
  UnitDef(
    id: 'dave',
    name: 'Bramble the Squire',
    tier: Tier.common,
    tags: ['Staff'],
    color: 0xFF5BA4E6,
    shape: Shape.square,
    mono: 'Br',
    dmg: 14,
    interval: 1.6,
    range: 1.9,
    splash: 0.8,
    desc:
        'Swings an oversized wooden mace. Small splash.',
    quip: 'Squire today. Knight tomorrow. Mace forever.',
  ),
  UnitDef(
    id: 'rock',
    name: 'Gil the Gumflask',
    tier: Tier.common,
    tags: ['Sweets'],
    color: 0xFFFF8FB8,
    shape: Shape.diamond,
    mono: 'Gi',
    dmg: 8,
    interval: 0.9,
    range: 2.6,
    slowPct: 0.2,
    slowDur: 1.0,
    desc:
        'Lobs sticky violet slime flasks. Slows 20%.',
    quip: 'It is meant to be that colour. Probably.',
  ),
  UnitDef(
    id: 'carl',
    name: 'Kip Copperfinger',
    tier: Tier.common,
    tags: ['Arcade'],
    color: 0xFFD4A84A,
    shape: Shape.hexagon,
    mono: 'Kp',
    dmg: 7,
    interval: 0.9,
    range: 2.4,
    killPennies: 1,
    desc:
        'Flicks coins. Weak, but every kill pays 1 penny.',
    quip: 'Finders keepers. Riftlings, losers weepers.',
  ),
  // ---------------- RARE ----------------
  UnitDef(
    id: 'thwack',
    name: 'Thump the Brawler Imp',
    tier: Tier.rare,
    tags: ['Arcade'],
    color: 0xFFE2483D,
    shape: Shape.circle,
    mono: 'Tp',
    dmg: 30,
    interval: 1.0,
    range: 2.1,
    stunChance: 0.15,
    stunDur: 0.8,
    desc:
        'Swings a knuckle-wrapped cudgel. 15% chance to stun.',
    quip: 'Thump. That is the name and the plan.',
  ),
  UnitDef(
    id: 'floss',
    name: 'Bubbla the Brewwitch',
    tier: Tier.rare,
    tags: ['Sweets'],
    color: 0xFFFFB3E1,
    shape: Shape.drop,
    mono: 'Bu',
    dmg: 18,
    interval: 1.0,
    range: 2.6,
    splash: 1.0,
    slowPct: 0.35,
    slowDur: 1.5,
    desc:
        'Blows sticky violet bubbles that splash. Slows 35%.',
    quip: 'Double, double, pop and bubble.',
  ),
  UnitDef(
    id: 'lou',
    name: 'Rook Sparkhelm',
    tier: Tier.rare,
    tags: ['Staff'],
    color: 0xFFFF6B4A,
    shape: Shape.shield,
    mono: 'Ro',
    dmg: 16,
    interval: 0.9,
    range: 3.0,
    chain: 2,
    desc:
        'His halberd arcs lightning that chains to 3 targets.',
    quip: 'Helm on. Hair up. Everything up, actually.',
  ),
  UnitDef(
    id: 'admiral',
    name: 'Captain Talonne',
    tier: Tier.rare,
    tags: ['Birds'],
    color: 0xFF9AA7B4,
    shape: Shape.star,
    mono: 'Ta',
    dmg: 20,
    interval: 0.7,
    range: 2.6,
    auraTag: 'Birds',
    auraSpeed: 0.25,
    auraRange: 2.2,
    desc:
        'Her signal horn: Skyborn within 2 cells attack 25% faster.',
    quip: 'Wings level. Eyes on the crack. FLY.',
  ),
  // ---------------- EPIC ----------------
  UnitDef(
    id: 'claw',
    name: 'Hesper Hookshot',
    tier: Tier.epic,
    tags: ['Arcade'],
    color: 0xFF7A5CFF,
    shape: Shape.square,
    mono: 'He',
    dmg: 70,
    interval: 1.4,
    range: 2.8,
    grabEvery: 4,
    desc:
        'Every 4th grab hooks a target and yanks it back down the lane.',
    quip: 'Going somewhere? Not any more.',
  ),
  UnitDef(
    id: 'sal',
    name: 'Brakka of the Emberforge',
    tier: Tier.epic,
    tags: ['Staff'],
    color: 0xFFFFA62B,
    shape: Shape.hexagon,
    mono: 'Bk',
    dmg: 40,
    interval: 1.5,
    range: 2.4,
    splash: 1.0,
    burnDps: 45,
    burnDur: 3,
    desc:
        'Swings a molten hammer: splash plus a 3s burn.',
    quip: 'Forged in the Emberforge. Cooled on your face.',
  ),
  UnitDef(
    id: 'morag',
    name: 'Nerys Coralhex',
    tier: Tier.epic,
    tags: ['Sea'],
    color: 0xFF6FD3C8,
    shape: Shape.drop,
    mono: 'Ne',
    dmg: 50,
    interval: 1.0,
    range: 3.0,
    multi: 2,
    cursePct: 0.25,
    curseDur: 4,
    desc:
        'Her coral staff curses 2 targets: they take 25% more damage, armour ignored.',
    quip: 'The tide told me your name. It was not impressed.',
  ),
  UnitDef(
    id: 'squall',
    name: 'Zephra the Gale Dancer',
    tier: Tier.epic,
    tags: ['Birds'],
    color: 0xFFF2F2F2,
    shape: Shape.star,
    mono: 'Ze',
    dmg: 30,
    interval: 0.8,
    range: 2.8,
    multi: 4,
    desc:
        'Throws four razor feathers: hits 4 targets at once.',
    quip: 'One fan for the wind. One fan for you.',
  ),
  // ---------------- LEGENDARY ----------------
  UnitDef(
    id: 'vex',
    name: 'Duchess Vanta, Card Sharp',
    tier: Tier.legendary,
    tags: ['Arcade'],
    color: 0xFFB04BFF,
    shape: Shape.circle,
    mono: 'Va',
    dmg: 200,
    interval: 1.0,
    range: 3.2,
    critChance: 0.25,
    critMult: 3,
    killPennies: 2,
    desc:
        'Razor cards: 25% to crit for 3x. Kills pay 2 pennies.',
    quip: 'Pick a card. Any card. They all cut.',
  ),
  UnitDef(
    id: 'bertie',
    name: 'Gyro the Clockwork Knight',
    tier: Tier.legendary,
    tags: ['Arcade'],
    color: 0xFFFF4F9A,
    shape: Shape.hexagon,
    mono: 'Gy',
    dmg: 170,
    interval: 2.0,
    range: 3.4,
    pulse: true,
    desc:
        'Spins his blades: every 2s hits everything in range.',
    quip: 'Wind me up and stand well back.',
  ),
  UnitDef(
    id: 'keeper',
    name: 'Oshen the Tidecaller',
    tier: Tier.legendary,
    tags: ['Sea'],
    color: 0xFFFFE066,
    shape: Shape.triangle,
    mono: 'Os',
    dmg: 420,
    interval: 1.2,
    range: 5.0,
    bossMult: 2,
    desc:
        'Huge range tidal beam. Double damage to bosses.',
    quip: 'The sea is patient. I am the sea, briefly impatient.',
  ),
  UnitDef(
    id: 'albatross',
    name: 'Vael the Skywarden',
    tier: Tier.legendary,
    tags: ['Birds'],
    color: 0xFF8FB3D9,
    shape: Shape.star,
    mono: 'Vl',
    dmg: 150,
    interval: 0.9,
    range: 3.6,
    multi: 2,
    cursePct: 0.15,
    curseDur: 3,
    desc:
        'Hovers over 2 targets at once. They take 15% more damage.',
    quip: 'From up here every riftling looks small. Because they are.',
  ),
  // ---------------- MYTHIC (recipes) ----------------
  UnitDef(
    id: 'tide',
    name: 'Thalassa, Heart of the Deep',
    tier: Tier.mythic,
    tags: ['Sea'],
    color: 0xFF2EC4FF,
    shape: Shape.drop,
    mono: 'Th',
    dmg: 520,
    interval: 1.0,
    range: 3.5,
    splash: 1.2,
    freezeEvery: 8,
    freezeDur: 1.5,
    freezeDmg: 650,
    desc:
        'Every 8s her whirlpool rises: everything freezes 1.5s and takes 650.',
    quip: 'All water returns to me, little ones. So will you.',
  ),
  UnitDef(
    id: 'jackpot',
    name: 'The Gilded Djinn',
    tier: Tier.mythic,
    tags: ['Arcade'],
    color: 0xFFFFD700,
    shape: Shape.star,
    mono: 'Dj',
    dmg: 300,
    interval: 0.9,
    range: 3.2,
    jackpotEvery: 10,
    pennyScale: 2,
    desc:
        'Hits harder the more pennies you hold. Every 10th pull: JACKPOT.',
    quip: 'Three wishes? Three cherries. Same thing.',
  ),
  UnitDef(
    id: 'velvet',
    name: 'Maestra Valenne',
    tier: Tier.mythic,
    tags: ['Staff'],
    color: 0xFFD6336C,
    shape: Shape.shield,
    mono: 'Mv',
    dmg: 420,
    interval: 0.8,
    range: 3.2,
    auraTag: 'all',
    auraSpeed: 0.3,
    auraRange: 99,
    executePct: 0.12,
    desc:
        'Conducts the board: every figurine attacks 30% faster. Finishes non-bosses under 12%.',
    quip: 'And one, and two, and STRIKE.',
  ),
  UnitDef(
    id: 'gullivan',
    name: 'Solenne, Seraph of Quills',
    tier: Tier.mythic,
    tags: ['Birds'],
    color: 0xFFFFFFFF,
    shape: Shape.triangle,
    mono: 'So',
    dmg: 160,
    interval: 0.25,
    range: 3.0,
    perBird: 0.06,
    desc:
        'A stream of golden quills. +6% damage for every Skyborn on your board.',
    quip: 'Every feather is a prayer. Every prayer is pointed.',
  ),
];

final Map<String, UnitDef> kUnitById = {for (final u in kUnits) u.id: u};

List<UnitDef> unitsOfTier(Tier t) => kUnits.where((u) => u.tier == t).toList();

/// Mythic recipes: one of each ingredient anywhere on your board.
const Map<String, List<String>> kRecipes = {..._kRecipesBase, ...kRecipesNew};

const Map<String, List<String>> _kRecipesBase = {
  'tide': ['keeper', 'morag', 'lou'],
  'jackpot': ['vex', 'claw', 'carl'],
  'velvet': ['bertie', 'sal', 'floss'],
  'gullivan': ['albatross', 'squall', 'admiral'],
};

// ---------------- Summon odds ----------------
/// Base summon odds, percent: common, rare, epic, legendary.
const List<double> kBaseOdds = [70, 24, 5, 1];

/// Change per Lucky Penny level.
const List<double> kLuckShift = [-4, 2, 1.5, 0.5];
const int kMaxLuck = 5;

List<double> summonOdds(int luck) {
  final l = luck.clamp(0, kMaxLuck);
  return [for (var i = 0; i < 4; i++) kBaseOdds[i] + kLuckShift[i] * l];
}

int luckUpgradeCost(int luck) => 60 + 40 * luck;

// ---------------- Gambling (Read the Leaves) ----------------
class GambleOption {
  final Tier tier;
  final int cost;
  final double chance;
  const GambleOption(this.tier, this.cost, this.chance);
}

const List<GambleOption> kGambles = [
  GambleOption(Tier.rare, 1, 0.60),
  GambleOption(Tier.epic, 1, 0.20),
  GambleOption(Tier.legendary, 2, 0.10),
];

// ---------------- Economy ----------------
const int kStartPennies = 100;
const int kSummonBaseCost = 20;
const int kSummonStep = 1;
const int kBoardCols = 6;
const int kBoardRows = 3;
const int kStackMax = 3;
const int kLaneLimit = 100;
const double kWaveSeconds = 20;
const double kBossSeconds = 60;

/// Calm pacing from wave 19 to 48. In waves [kPaceFrom] to [kPaceTo] the next
/// wave waits while its spawns are still coming out or more than
/// [kPaceCrowd] riftlings are still out, for up to [kPaceHoldMax] extra
/// seconds, so the board can clear each wave before the next one lands and
/// the wave 30/40/50 bosses don't arrive behind a pile (14-32 left by wave
/// 29 without it). Waves are not thinned, so kills (and pennies) stay the
/// same. Calm only; Choppy and Storm keep the flat [kWaveSeconds]. It stops
/// at 48 so the final boss still arrives into a busy board and stays a fight
/// (holding wave 49 too left it under a third of its timer used in Solo).
/// tool/death_probe.dart, seeds 1000-1023: Calm co-op 63% -> 88%, solo
/// 42% -> 83%; winning runs about 17 -> 20 minutes.
final int kPaceFrom = int.parse(
  const String.fromEnvironment('PACEFROM', defaultValue: '19'),
);
final int kPaceTo = int.parse(
  const String.fromEnvironment('PACETO', defaultValue: '48'),
);
final int kPaceCrowd = int.parse(
  const String.fromEnvironment('PACECROWD', defaultValue: '2'),
);
final double kPaceHoldMax = double.parse(
  const String.fromEnvironment('PACEHOLD', defaultValue: '30'),
);

/// Waves in one level. Beat the final boss on this wave to clear the level.
const int kFinalWave = 50;
const int kRerollPennies = 12;

/// Summons in a row that can be Common before the machine takes pity.
const int kMercyStreak = 7;

/// Coins from a kill, by wave.
int killReward(int wave) => 2 + wave ~/ 8;

/// Wages paid at the start of every wave.
int waveWages(int wave) => 10 + 2 * wave;

int sellPennies(Tier t) => const [8, 20, 0, 0, 0][t.index];
int sellLeaves(Tier t) => const [0, 0, 1, 3, 0][t.index];

/// Elbow Grease: damage upgrades per group. Groups: 0 = common+rare,
/// 1 = epic, 2 = legendary+mythic.
int upgradeGroup(Tier t) => t.index <= 1 ? 0 : (t == Tier.epic ? 1 : 2);
const List<String> kUpgradeGroupNames = [
  'Common & Rare',
  'Epic',
  'Legend & Mythic',
];
int upgradeCost(int group, int level) =>
    [30, 50, 80][group] + [25, 40, 60][group] * level;
const double kUpgradeStep = 0.12;
const int kMaxUpgrade = 15;

// ---------------- Enemies ----------------
class EnemyDef {
  final String id;
  final String name;
  final double hpMult;
  final double speed;
  final double armor;
  final double evade;
  final double healAura;
  final String? splitInto;
  final int splitCount;
  final int color;
  final int body; // drawing style
  final double size;
  final String blurb;

  /// Special behaviour (see [Trait]) and its numbers.
  final Trait trait;
  final double every;
  final double pow;

  /// How many places it takes toward the lane limit.
  final int weight;

  /// What it costs from a wave's threat budget.
  final int threat;
  const EnemyDef(
    this.id,
    this.name, {
    this.hpMult = 1,
    this.speed = 1,
    this.armor = 0,
    this.evade = 0,
    this.healAura = 0,
    this.splitInto,
    this.splitCount = 0,
    required this.color,
    this.body = 0,
    this.size = 0.32,
    required this.blurb,
    this.trait = Trait.none,
    this.every = 0,
    this.pow = 0,
    this.weight = 1,
    this.threat = 1,
  });
}

const List<EnemyDef> kEnemies = [..._kEnemiesBase, ...kEnemiesNew];

const List<EnemyDef> _kEnemiesBase = [
  EnemyDef(
    'drip',
    'Seep',
    color: 0xFF4FB286,
    blurb: 'A puddle with ambitions.',
  ),
  EnemyDef(
    'pinchy',
    trait: Trait.armor,
    threat: 2,
    'Riftpinch',
    hpMult: 1.4,
    speed: 0.75,
    armor: 0.4,
    color: 0xFFE85D3F,
    body: 1,
    size: 0.34,
    blurb: 'Armoured. Takes 40% less damage unless cursed.',
  ),
  EnemyDef(
    'eel',
    threat: 1,
    'Void Eel',
    hpMult: 0.6,
    speed: 1.9,
    color: 0xFF3F7CE8,
    body: 2,
    size: 0.28,
    blurb: 'Fast. Slippery. Smug.',
  ),
  EnemyDef(
    'wobbler',
    trait: Trait.split,
    threat: 2,
    'Wobbler',
    hpMult: 1.1,
    speed: 0.9,
    splitInto: 'wibble',
    splitCount: 2,
    color: 0xFFD27BFF,
    body: 3,
    size: 0.34,
    blurb: 'Pops into two Wibbles.',
  ),
  EnemyDef(
    'wibble',
    threat: 1,
    'Flicker',
    hpMult: 0.3,
    speed: 1.3,
    color: 0xFFE7B3FF,
    body: 3,
    size: 0.2,
    blurb: 'Half a Wobbler. Twice the attitude.',
  ),
  EnemyDef(
    'nanny',
    trait: Trait.heal,
    threat: 2,
    'Rift Nanny',
    hpMult: 1.6,
    speed: 0.8,
    healAura: 0.03,
    color: 0xFF2E8B57,
    body: 4,
    size: 0.36,
    blurb: 'Heals nearby riftlings 3% a second. Kill her first.',
  ),
  EnemyDef(
    'mist',
    trait: Trait.dodge,
    threat: 2,
    'Rift Mist',
    hpMult: 0.8,
    speed: 1.2,
    evade: 0.35,
    color: 0xFFB8C7D9,
    body: 5,
    blurb: 'Dodges 35% of hits.',
  ),
  EnemyDef(
    'pollock',
    trait: Trait.bonus,
    threat: 1,
    'Glintfish',
    hpMult: 2.0,
    speed: 2.4,
    color: 0xFFFFD34D,
    body: 2,
    size: 0.3,
    blurb: 'Rare. Kill it within one lap for a tea leaf and 15 pennies.',
  ),
  EnemyDef(
    'bigdrip',
    trait: Trait.split,
    threat: 8,
    'Big Seep',
    hpMult: 8,
    speed: 0.7,
    color: 0xFF1F8A5C,
    body: 0,
    size: 0.5,
    blurb: 'Every fifth wave. A lot of drip.',
  ),
  EnemyDef(
    'bailiff',
    threat: 2,
    'Void Bailiff',
    hpMult: 1.5,
    speed: 0.9,
    armor: 0.3,
    color: 0xFF444B57,
    body: 1,
    size: 0.34,
    blurb: 'Works for the Landlord. Armoured.',
  ),
  EnemyDef(
    'flyer',
    trait: Trait.flying,
    threat: 2,
    'Rift Dart',
    hpMult: 0.5,
    speed: 2.3,
    evade: 0.15,
    color: 0xFF7FB8D9,
    body: 2,
    size: 0.28,
    blurb: 'A flying fish. Very fast, very rude, dodges 15% of hits.',
  ),
  EnemyDef(
    'barnacle',
    trait: Trait.grow,
    threat: 3,
    'Rift Barnacle',
    hpMult: 2.4,
    speed: 0.55,
    armor: 0.5,
    color: 0xFF6C7A72,
    body: 1,
    size: 0.36,
    blurb: 'A rock with legs. Slow, and takes half damage unless cursed.',
  ),
  EnemyDef(
    'star',
    trait: Trait.pair,
    threat: 2,
    'Spinstar',
    hpMult: 0.75,
    speed: 2.0,
    color: 0xFFF07A8A,
    body: 2,
    size: 0.28,
    blurb: 'Spins down the path like a thrown plate.',
  ),
  EnemyDef(
    'hermit',
    trait: Trait.tin,
    threat: 2,
    'Hollow Hermit',
    hpMult: 1.4,
    speed: 0.85,
    armor: 0.55,
    color: 0xFFE8743B,
    body: 1,
    size: 0.32,
    blurb: 'Lives in a sardine tin. Takes 55% less damage unless cursed.',
  ),
  EnemyDef(
    'puffer',
    trait: Trait.puff,
    threat: 3,
    'Void Puffer',
    hpMult: 2.8,
    speed: 0.75,
    color: 0xFFF59B2B,
    body: 3,
    size: 0.36,
    blurb: 'Swells up to soak hits. Lots of health.',
  ),
  EnemyDef(
    'octo',
    trait: Trait.ink,
    threat: 2,
    'Octo-Tot',
    hpMult: 0.9,
    speed: 1.25,
    evade: 0.2,
    splitInto: 'wibble',
    splitCount: 2,
    color: 0xFFA77BE0,
    body: 3,
    size: 0.3,
    blurb: 'Dodges 20% of hits and leaves two Wibbles behind.',
  ),
  EnemyDef(
    'angler',
    trait: Trait.lure,
    threat: 3,
    'Lampjaw',
    hpMult: 1.7,
    speed: 0.9,
    healAura: 0.025,
    color: 0xFF2D5C8A,
    body: 4,
    size: 0.34,
    blurb: 'Its lamp heals nearby riftlings 2.5% a second.',
  ),
  EnemyDef(
    'voidling',
    trait: Trait.blink,
    threat: 2,
    'Voidling',
    hpMult: 1.5,
    speed: 1.1,
    armor: 0.2,
    evade: 0.25,
    color: 0xFF4B2A7A,
    body: 5,
    size: 0.32,
    blurb:
        'A hole in the world. Dodges 25% of hits and shrugs off 20% of damage.',
  ),
];

final Map<String, EnemyDef> kEnemyById = {for (final e in kEnemies) e.id: e};

/// Ordinary riftlings (not bosses) have this much more health than
/// [baseHp], so the lane can actually fill up between bosses.
const double kCrowdHpMult = 1.2;

/// Base health of one ordinary enemy at [wave], Co-op, Calm.
double baseHp(int wave) {
  // Steep early (your board is growing fast), gentler late (it has filled up).
  var hp = 150.0;
  for (var w = 2; w <= wave; w++) {
    hp *= w <= 15 ? 1.15 : (w <= 30 ? 1.12 : 1.07);
  }
  return hp;
}

/// Ordinary enemies spawned in a wave (the old fixed count, kept as the
/// yardstick the threat budget is measured against).
int spawnCount(int wave) => 16 + (wave ~/ 3);

/// The threat a wave can spend on enemies. A Drip costs 1; tougher or
/// trickier things cost more, so later waves get harder through what turns up,
/// not just through health.
int threatBudget(int wave, [int level = 1]) =>
    (spawnCount(wave) * (1.25 + 0.012 * wave) * (1 + 0.04 * (_lv(level) - 1)))
        .round();

int _lv(int level) => ((level - 1) % kLevels.length) + 1;

/// Which enemy types can appear on [wave] of [level] (its roster up to now).
List<String> enemyPool(int wave, [int level = 1]) {
  final r = kLevelRoster[_lv(level)]!;
  final p = <String>['drip'];
  for (final e in r.entries) {
    if (e.key != 'drip' && wave >= e.value) p.add(e.key);
  }
  return p;
}

/// The type that is brand new on [wave] of [level], if any. Its wave is a
/// showcase: it arrives alone with Seeps.
String? showcaseFor(int wave, [int level = 1]) {
  for (final e in kLevelRoster[_lv(level)]!.entries) {
    if (e.value == wave && e.key != 'drip' && wave > 1) return e.key;
  }
  return null;
}

bool isBossWave(int wave) => wave % 10 == 0;
bool isMiniBossWave(int wave) => wave % 10 == 5;

// ---------------- Bosses ----------------
enum BossMech {
  brood,
  inspector,
  undertow,
  landlord,
  cuttle,
  kingcrab,
  prizeclaw,
  limpet,
  ringmaster,
  wrecker,
  redactor,
  ghosttrain,
  shadowkeeper,
  voidboss,
  auditor,
  severer,
  choir,
  colossus,
}

class BossDef {
  final String id;
  final String name;
  final String title;
  final BossMech mech;
  final double hpMult; // times baseHp(wave)
  final double speed;
  final double armor;
  final int color;
  final String entrance;
  final String defeat;
  final String mechText;

  /// What a brood boss spits out.
  final String spawn;
  const BossDef(
    this.id,
    this.name,
    this.title,
    this.mech, {
    required this.hpMult,
    this.spawn = 'drip',
    required this.speed,
    this.armor = 0,
    required this.color,
    required this.entrance,
    required this.defeat,
    required this.mechText,
  });
}

const List<BossDef> kBosses = [
  BossDef(
    'brine',
    'Mother Brine',
    'She Who Puddles',
    BossMech.brood,
    hpMult: 7,
    speed: 0.55,
    color: 0xFF2FA36B,
    entrance: 'My babies. Go and play by the nice Rift.',
    defeat: 'Mind... the... wet... floor...',
    mechText: 'Spawns three Seeps every 6 seconds.',
  ),
  BossDef(
    'inspector',
    'The Rift Inspector',
    'Department of Rifts',
    BossMech.inspector,
    hpMult: 9.5,
    speed: 0.6,
    armor: 0.15,
    color: 0xFF8E9AAF,
    entrance: 'Right. Nobody move. This is an inspection.',
    defeat: 'I will be... filing a... complaint...',
    mechText: 'Every 7s condemns your strongest cell for 4s. Immune to stun and slow.',
  ),
  BossDef(
    'undertow',
    'The Undertow',
    'The Pull Beneath',
    BossMech.undertow,
    hpMult: 9.5,
    speed: 0.65,
    color: 0xFF1B4F72,
    entrance: '...come... down... with... us...',
    defeat: 'the... tide... always... turns...',
    mechText: 'Every 9s dives for 2.5s: untargetable, heals 4%, then surges.',
  ),
  BossDef(
    'landlord',
    'The Landlord',
    'Owner of Everything',
    BossMech.landlord,
    hpMult: 9,
    speed: 0.5,
    armor: 0.2,
    color: 0xFF6B2D5C,
    entrance: 'Lovely little Rift. Shame about the rent.',
    defeat: 'You can keep the Rift. It is falling into itself anyway.',
    mechText: 'Takes 15% of your pennies each lap. Shields and calls Bailiffs at 66% and 33%.',
  ),
  BossDef(
    'cuttle',
    'Captain Cuttle',
    'Terror of the Arcade',
    BossMech.cuttle,
    hpMult: 11,
    speed: 0.6,
    armor: 0.1,
    color: 0xFFD9822B,
    entrance: 'Arr. This Rift be mine now. All of it. Even the toilets.',
    defeat: 'Abandon... Rift...',
    mechText: 'Ink Column: every 10s inks one column of your board, halving its range for 4s. Plunder: at 66% and 33% four Token Thieves join him.',
  ),
  BossDef(
    'kingcrab',
    'King Crabbington',
    'Lord of the Cove',
    BossMech.kingcrab,
    hpMult: 12,
    speed: 0.5,
    armor: 0.3,
    color: 0xFFC0392B,
    entrance: 'Kneel. Or at least shuffle sideways respectfully.',
    defeat: 'Long live... me...',
    mechText: 'Molting: at 66% and 33% he sheds his shell. The Shell Husk walks on with his armour (counts as 10) while he runs bare and 40% faster for 8s. Pinchies escort him.',
  ),
  BossDef(
    'void',
    'The Void',
    'What Came Through the Rift',
    BossMech.voidboss,
    hpMult: 13,
    speed: 0.5,
    armor: 0.15,
    color: 0xFF6A3FD9,
    spawn: 'voidling',
    entrance: '...',
    defeat: '...oh.',
    mechText: 'Event Horizon pulls things close; inside its ring only area and Lightbringer hits land. At 66% it replays every earlier final. At 25% the lane limit drops to 80.',
  ),
];

const List<BossDef> kBossesNew = [
  BossDef(
    'prizeclaw',
    'The Prize Claw',
    'Everybody Wins (Nobody Wins)',
    BossMech.prizeclaw,
    hpMult: 9.5,
    speed: 0.55,
    armor: 0.1,
    color: 0xFFB0BEC5,
    entrance: 'Insert coin. Insert coin. INSERT COIN.',
    defeat: 'Game... over...',
    mechText: 'A crosshair sits on a cell for 2s, then the claw lifts its top figurine (never a Mythic). It comes back when the Claw loses 15% health or after 12s. Drag it away from the crosshair.',
  ),
  BossDef(
    'limpet',
    'Lady Limpet',
    'She Will Not Be Moved',
    BossMech.limpet,
    hpMult: 9.5,
    speed: 0.5,
    armor: 0.15,
    color: 0xFF6D597A,
    spawn: 'barnacle',
    entrance: 'I have clung to this crack since before your grandmother.',
    defeat: 'Unclamping... with dignity...',
    mechText: 'Every 10s she clamps on: stops with 70% armour for 5s while everything else moves 30% faster. Burst her while she moves.',
  ),
  BossDef(
    'ringmaster',
    'The Ringmaster',
    'Roll Up, Roll Up',
    BossMech.ringmaster,
    hpMult: 9.5,
    speed: 0.55,
    armor: 0.1,
    color: 0xFF9B2226,
    entrance: 'Ladies and gentlemen, the main event: YOUR DOWNFALL.',
    defeat: 'The show... must... stop...',
    mechText: 'Every 12s calls an act, named 2s before: Clowns (six fast adds), Lion (an armoured brute) or Knife Thrower (his next 5 hits miss).',
  ),
  BossDef(
    'wrecker',
    'The Wrecker',
    'False Light on the Rocks',
    BossMech.wrecker,
    hpMult: 9.5,
    speed: 0.55,
    armor: 0.1,
    color: 0xFF495057,
    entrance: 'Follow the light, little ships. Follow it right onto the rocks.',
    defeat: 'The light... goes out...',
    mechText: 'Every 9s lights a false lantern. For 3s single-target figurines shoot it until it breaks after 8 hits. Area and multi-target ignore it.',
  ),
  BossDef(
    'redactor',
    'The Redactor',
    '[REDACTED]',
    BossMech.redactor,
    hpMult: 10,
    speed: 0.55,
    armor: 0.15,
    color: 0xFF212529,
    entrance: 'Your unions have been reviewed. Several are now ████████.',
    defeat: 'This defeat... did not... happen...',
    mechText: 'Every 12s crosses out one of your active union rules for 8s (struck through 2s before). Don\'t lean on one union.',
  ),
  BossDef(
    'ghosttrain',
    'The Ghost Train',
    'Last Departure',
    BossMech.ghosttrain,
    hpMult: 12,
    speed: 0.55,
    armor: 0.1,
    color: 0xFF1B4332,
    entrance: 'WHOOOOO. All aboard. There is no getting off.',
    defeat: 'Terminus...',
    mechText: 'An engine and five carriages. Only the rear carriage can be hit; each one destroyed makes it 10% faster and drops a passenger. Every 15s it whistles and hides in a tunnel for 2s.',
  ),
  BossDef(
    'shadowkeeper',
    'The Shadow Keeper',
    'What the Light Left Behind',
    BossMech.shadowkeeper,
    hpMult: 12.5,
    speed: 0.5,
    armor: 0.1,
    color: 0xFF240046,
    entrance: 'I kept the lamp for forty years. Now I keep the dark.',
    defeat: 'Someone... light... the lamp...',
    mechText: 'Every 10s adapts to what hurt him most (single-target, area or status) and takes 50% less from it. At 50% his shadow silences three cells for 5s.',
  ),
  BossDef(
    'auditor',
    'The Auditor',
    'Everything Is Deductible',
    BossMech.auditor,
    hpMult: 9.5,
    speed: 0.55,
    armor: 0.15,
    color: 0xFF495057,
    entrance: 'Pennies, is it? Let us see the receipts.',
    defeat: 'This... will be... appealed...',
    mechText: 'While he is out, the Hoard bonus is off. Every 9s he takes one penny in ten from each side, up to 25. Spend before he arrives.',
  ),
  BossDef(
    'severer',
    'The Severer',
    'Snip, Snip',
    BossMech.severer,
    hpMult: 9.5,
    speed: 0.55,
    armor: 0.1,
    color: 0xFF9D0208,
    entrance: 'Such sweet little friendships. Hold still.',
    defeat: 'Frayed...',
    mechText: 'Every 12s cuts every bond for 5s (warned 2s before). Unions still work. Build a board that stands without its pairs.',
  ),
  BossDef(
    'hollowchoir',
    'The Hollow Choir',
    'All Together Now',
    BossMech.choir,
    hpMult: 9,
    speed: 0.5,
    armor: 0.1,
    color: 0xFF354F52,
    spawn: 'revenant',
    entrance: 'One voice drowned. Then another. Now we sing.',
    defeat: 'The... last... verse...',
    mechText: 'Every 10s raises three Twice-Drowned beside it. They get back up once unless area damage finishes them.',
  ),
  BossDef(
    'colossus',
    'The Glass Colossus',
    'Handle With Care',
    BossMech.colossus,
    hpMult: 8,
    speed: 0.45,
    armor: 0,
    color: 0xFFBDE0FE,
    spawn: 'plated',
    entrance: 'Careful. I chip.',
    defeat: '*crack*',
    mechText: 'No single hit takes more than 3% of its health, so fast and many-hit figurines matter most. Every 12s two Glass Grubs break off it.',
  ),
];

final Map<String, BossDef> kBossById = {
  for (final b in [...kBosses, ...kBossesNew]) b.id: b,
};

// ---------------- Levels ----------------
class LevelDef {
  final String name;
  final String blurb;
  final String finalBoss;
  final double hpMult;
  final LevelRule rule;

  /// The level's own warden (waves 10 and 30) and the earlier warden that
  /// comes back on wave 20 and shares the bill on wave 40.
  final String warden;
  final String guest;
  const LevelDef(
    this.name,
    this.blurb,
    this.finalBoss,
    this.hpMult, {
    this.rule = LevelRule.none,
    this.warden = 'brine',
    this.guest = 'inspector',
  });
}

/// Six levels, 50 waves each. Health only climbs 1.0x to 1.5x across them:
/// the rest of the difficulty is enemy mechanics and compositions.
const List<LevelDef> kLevels = [
  LevelDef(
    'The Breach',
    'The Rift has just torn open. Something is climbing out.',
    'landlord',
    1.0,
    warden: 'brine',
    guest: 'inspector',
  ),
  LevelDef(
    'The Fogbound Arcade',
    'The Rift breathes fog, and a drowned pirate rode it in.',
    'cuttle',
    1.1,
    rule: LevelRule.fog,
    warden: 'prizeclaw',
    guest: 'undertow',
  ),
  LevelDef(
    'Shattered Cove',
    'The Rift split the cove. Shells, claws and a crab who thinks he is royalty.',
    'kingcrab',
    1.2,
    rule: LevelRule.tide,
    warden: 'limpet',
    guest: 'auditor',
  ),
  LevelDef(
    'The Rift Fair',
    'The rides are still running. Nobody is operating them.',
    'ghosttrain',
    1.3,
    rule: LevelRule.rides,
    warden: 'ringmaster',
    guest: 'severer',
  ),
  LevelDef(
    'The Dark Lamp',
    'The lamp still turns. The keeper does not.',
    'shadowkeeper',
    1.4,
    rule: LevelRule.beam,
    warden: 'wrecker',
    guest: 'hollowchoir',
  ),
  LevelDef(
    'The Rift\'s Edge',
    'The edge of the world is not where it used to be.',
    'void',
    1.5,
    rule: LevelRule.statik,
    warden: 'redactor',
    guest: 'colossus',
  ),
];

/// Level [n], counting from 1. Past the last one the list repeats (Endless
/// only) and every lap of it is 1.6 times tougher.
LevelDef levelDef(int n) {
  final i = (n - 1) % kLevels.length;
  final lap = (n - 1) ~/ kLevels.length;
  final base = kLevels[i];
  if (lap == 0) return base;
  return LevelDef(
    '${base.name} ${_roman(lap + 1)}',
    base.blurb,
    base.finalBoss,
    base.hpMult * _pow(1.6, lap) * 1.5,
    rule: base.rule,
    warden: base.warden,
    guest: base.guest,
  );
}

double _pow(double b, int e) {
  var r = 1.0;
  for (var i = 0; i < e; i++) {
    r *= b;
  }
  return r;
}

String _roman(int n) => const [
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
  'IX',
  'X',
][(n - 1).clamp(0, 9)];

/// The bosses on a boss wave of [level]: the level's warden on 10, the
/// earlier guest warden on 20 (under this level's rule), the warden's second
/// form on 30, a double bill at 60% health each on 40, and the final on
/// [kFinalWave].
List<BossDef> bossesForWave(int wave, [int level = 1]) {
  final lv = levelDef(level);
  final w = wave % kFinalWave;
  if (w == 0) return [kBossById[lv.finalBoss]!];
  final slot = w ~/ 10;
  return switch (slot) {
    2 => [kBossById[lv.guest]!],
    4 => [kBossById[lv.warden]!, kBossById[lv.guest]!],
    _ => [kBossById[lv.warden]!],
  };
}

/// The first (or only) boss of a boss wave.
BossDef bossForWave(int wave, [int level = 1]) =>
    bossesForWave(wave, level).first;

/// Whether the boss on [wave] comes in its second form.
bool isSecondForm(int wave) => wave % kFinalWave == 30;

/// Whether [wave] is a double bill.
bool isDoubleBill(int wave) => wave % kFinalWave == 40;

// ---------------- Partner ----------------
const String kPartnerName = 'Brenda';
const List<String> kBrendaLines = [
  'I have worked this front for twenty years and I have never seen a crab come out of the Rift that angry.',
  'Feed the machine, love. The machine is hungry.',
  'If we survive this I am asking for a raise. A small one. A biscuit.',
  'Three of the same? Squash \'em. That is what my mother did.',
  'Do not look the Inspector in the eye. He feeds on eye contact.',
  'I put a penny in for you. Do not tell the manager.',
  'They keep going round. Like my ex-husband.',
  'That one is wearing a tiny hat. Shoot the hat.',
];
