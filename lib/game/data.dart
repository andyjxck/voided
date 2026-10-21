// Voided — all static game data: figurines, sea things, bosses, odds,
// economy constants. Everything tunable lives here.

/// Enemy health in Solo, as a fraction of Co-op health. One constant, on
/// purpose: tune it here and every enemy, mini-boss and boss follows.
/// Started at 0.65 (the brief). The balance sims (tool/balance.dart,
/// test/balance_test.dart) showed Solo clearly harder than Co-op at 0.65, and
/// closest to Co-op at about 0.5 — see DESIGN.md for the numbers.
const double kSoloHpMultiplier = 0.5;

/// Bosses also take [kSoloHpMultiplier] in Solo, times this. 1.0 means bosses
/// scale exactly like everything else (the sims showed they stay a fight).
const double kSoloBossExtra = 1.0;

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
  String get label => const ['Calm Seas', 'Choppy', 'Storm Warning'][index];
  double get hpMult => const [1.0, 1.45, 1.95][index];
  String get blurb => const [
    'Last night of the season. Should be quiet.',
    'The tide is in a mood. Enemies have 45% more health.',
    'The council has closed the pier. You have not. +95% enemy health.',
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

// Tags (the "unions" on the pier). Three different figurines of one union on
// your board switches its union rule on.
const Map<String, String> kUnionRules = {
  'Birds': 'Birds attack 20% faster',
  'Staff': 'Staff hit 20% harder',
  'Sweets': 'Sweets slow 50% harder and longer',
  'Arcade': '+1 penny every 8 kills by Arcade',
  'Sea': 'Sea figurines get +0.6 range',
};

const List<UnitDef> kUnits = [
  // ---------------- COMMON ----------------
  UnitDef(
    id: 'gull',
    name: 'Gull With A Grudge',
    tier: Tier.common,
    tags: ['Birds'],
    color: 0xFFE8EEF2,
    shape: Shape.triangle,
    mono: 'Gu',
    dmg: 6,
    interval: 0.6,
    range: 2.6,
    desc: 'Fast pecks at one target.',
    quip: 'Chips. Now. Or else.',
  ),
  UnitDef(
    id: 'dave',
    name: 'Deckchair Dave',
    tier: Tier.common,
    tags: ['Staff'],
    color: 0xFF5BA4E6,
    shape: Shape.square,
    mono: 'Dv',
    dmg: 14,
    interval: 1.6,
    range: 1.9,
    splash: 0.8,
    desc: 'Swings a deckchair. Small splash.',
    quip: 'I have been folding this since 1987.',
  ),
  UnitDef(
    id: 'rock',
    name: 'Rock Candy Kid',
    tier: Tier.common,
    tags: ['Sweets'],
    color: 0xFFFF8FB8,
    shape: Shape.diamond,
    mono: 'Rk',
    dmg: 8,
    interval: 0.9,
    range: 2.6,
    slowPct: 0.2,
    slowDur: 1.0,
    desc: 'Sticky rock. Slows 20%.',
    quip: 'It says GRIMLEY all the way through. Like me.',
  ),
  UnitDef(
    id: 'carl',
    name: 'Coin-Pusher Carl',
    tier: Tier.common,
    tags: ['Arcade'],
    color: 0xFFD4A84A,
    shape: Shape.hexagon,
    mono: 'Cp',
    dmg: 7,
    interval: 0.9,
    range: 2.4,
    killPennies: 1,
    desc: 'Weak, but every kill pays 1 penny.',
    quip: 'Nearly. Nearly. NEARLY.',
  ),
  // ---------------- RARE ----------------
  UnitDef(
    id: 'thwack',
    name: 'Mister Thwack',
    tier: Tier.rare,
    tags: ['Arcade'],
    color: 0xFFE2483D,
    shape: Shape.circle,
    mono: 'Th',
    dmg: 30,
    interval: 1.0,
    range: 2.1,
    stunChance: 0.15,
    stunDur: 0.8,
    desc: 'Puppet with a stick. 15% chance to stun.',
    quip: 'That is NOT how you do it.',
  ),
  UnitDef(
    id: 'floss',
    name: 'Candyfloss Nan',
    tier: Tier.rare,
    tags: ['Sweets'],
    color: 0xFFFFB3E1,
    shape: Shape.drop,
    mono: 'Nn',
    dmg: 18,
    interval: 1.0,
    range: 2.6,
    splash: 1.0,
    slowPct: 0.35,
    slowDur: 1.5,
    desc: 'Sticky splash. Slows 35%.',
    quip: 'You look thin. Have some floss, love.',
  ),
  UnitDef(
    id: 'lou',
    name: 'Lifeguard Lou',
    tier: Tier.rare,
    tags: ['Staff'],
    color: 0xFFFF6B4A,
    shape: Shape.shield,
    mono: 'Lo',
    dmg: 16,
    interval: 0.9,
    range: 3.0,
    chain: 2,
    desc: 'Whistle blast chains to 3 targets.',
    quip: 'NO. RUNNING. ON. THE. PIER.',
  ),
  UnitDef(
    id: 'admiral',
    name: 'Admiral Tinbeak',
    tier: Tier.rare,
    tags: ['Birds'],
    color: 0xFF9AA7B4,
    shape: Shape.star,
    mono: 'Ad',
    dmg: 20,
    interval: 0.7,
    range: 2.6,
    auraTag: 'Birds',
    auraSpeed: 0.25,
    auraRange: 2.2,
    desc: 'Birds within 2 cells attack 25% faster.',
    quip: 'Formation! FORMATION! Oh, they have gone.',
  ),
  // ---------------- EPIC ----------------
  UnitDef(
    id: 'claw',
    name: 'The Claw',
    tier: Tier.epic,
    tags: ['Arcade'],
    color: 0xFF7A5CFF,
    shape: Shape.square,
    mono: 'Cl',
    dmg: 70,
    interval: 1.4,
    range: 2.8,
    grabEvery: 4,
    desc: 'Every 4th grab drags a target back down the lane.',
    quip: 'It is rigged. It has always been rigged.',
  ),
  UnitDef(
    id: 'sal',
    name: 'Big Sal the Fryer',
    tier: Tier.epic,
    tags: ['Staff'],
    color: 0xFFFFA62B,
    shape: Shape.hexagon,
    mono: 'Sa',
    dmg: 40,
    interval: 1.5,
    range: 2.4,
    splash: 1.0,
    burnDps: 45,
    burnDur: 3,
    desc: 'Flings hot oil: splash plus a 3s burn.',
    quip: 'Salt and vinegar? You are getting both.',
  ),
  UnitDef(
    id: 'morag',
    name: 'Fogwife Morag',
    tier: Tier.epic,
    tags: ['Sea'],
    color: 0xFF6FD3C8,
    shape: Shape.drop,
    mono: 'Mo',
    dmg: 50,
    interval: 1.0,
    range: 3.0,
    multi: 2,
    cursePct: 0.25,
    curseDur: 4,
    desc: 'Curses 2 targets: they take 25% more damage, armour ignored.',
    quip: 'The sea told me your name. It mispronounced it.',
  ),
  UnitDef(
    id: 'squall',
    name: 'Squall of Gulls',
    tier: Tier.epic,
    tags: ['Birds'],
    color: 0xFFF2F2F2,
    shape: Shape.star,
    mono: 'Sq',
    dmg: 30,
    interval: 0.8,
    range: 2.8,
    multi: 4,
    desc: 'Hits 4 targets at once.',
    quip: 'MINE MINE MINE MINE MINE.',
  ),
  // ---------------- LEGENDARY ----------------
  UnitDef(
    id: 'vex',
    name: 'Madame Vex',
    tier: Tier.legendary,
    tags: ['Arcade'],
    color: 0xFFB04BFF,
    shape: Shape.circle,
    mono: 'Vx',
    dmg: 200,
    interval: 1.0,
    range: 3.2,
    critChance: 0.25,
    critMult: 3,
    killPennies: 2,
    desc: '25% to crit for 3x. Kills pay 2 pennies.',
    quip: 'I foresee... a significant loss of pennies. Yours.',
  ),
  UnitDef(
    id: 'bertie',
    name: 'Big Wheel Bertie',
    tier: Tier.legendary,
    tags: ['Arcade'],
    color: 0xFFFF4F9A,
    shape: Shape.hexagon,
    mono: 'Bw',
    dmg: 170,
    interval: 2.0,
    range: 3.4,
    pulse: true,
    desc: 'Every 2s hits everything in range.',
    quip: 'Round and round. Nobody ever gets off.',
  ),
  UnitDef(
    id: 'keeper',
    name: 'The Lighthouse Keeper',
    tier: Tier.legendary,
    tags: ['Sea'],
    color: 0xFFFFE066,
    shape: Shape.triangle,
    mono: 'LK',
    dmg: 420,
    interval: 1.2,
    range: 5.0,
    bossMult: 2,
    desc: 'Huge range beam. Double damage to bosses.',
    quip: 'I keep the light. The light keeps nothing.',
  ),
  UnitDef(
    id: 'albatross',
    name: 'The Albatross',
    tier: Tier.legendary,
    tags: ['Birds'],
    color: 0xFF8FB3D9,
    shape: Shape.star,
    mono: 'Al',
    dmg: 150,
    interval: 0.9,
    range: 3.6,
    multi: 2,
    cursePct: 0.15,
    curseDur: 3,
    desc: 'Hangs over 2 targets at once. They take 15% more damage.',
    quip: 'I am not a bad omen. I am a VERY bad omen.',
  ),
  // ---------------- MYTHIC (recipes) ----------------
  UnitDef(
    id: 'tide',
    name: 'Old Mother Tide',
    tier: Tier.mythic,
    tags: ['Sea'],
    color: 0xFF2EC4FF,
    shape: Shape.drop,
    mono: 'MT',
    dmg: 520,
    interval: 1.0,
    range: 3.5,
    splash: 1.2,
    freezeEvery: 8,
    freezeDur: 1.5,
    freezeDmg: 650,
    desc: 'Every 8s the tide stops: everything freezes 1.5s and takes 650.',
    quip: 'Everything comes back to me, dear. Everything.',
  ),
  UnitDef(
    id: 'jackpot',
    name: 'The Jackpot',
    tier: Tier.mythic,
    tags: ['Arcade'],
    color: 0xFFFFD700,
    shape: Shape.star,
    mono: 'JP',
    dmg: 300,
    interval: 0.9,
    range: 3.2,
    jackpotEvery: 10,
    pennyScale: 2,
    desc: 'Hits harder the more pennies you hold. Every 10th pull: JACKPOT.',
    quip: 'Three cherries. Three cherries. THREE CHERRIES.',
  ),
  UnitDef(
    id: 'velvet',
    name: 'Velvet, the Headliner',
    tier: Tier.mythic,
    tags: ['Staff'],
    color: 0xFFD6336C,
    shape: Shape.shield,
    mono: 'Ve',
    dmg: 420,
    interval: 0.8,
    range: 3.2,
    auraTag: 'all',
    auraSpeed: 0.3,
    auraRange: 99,
    executePct: 0.12,
    desc: 'Every figurine attacks 30% faster. Finishes non-bosses under 12%.',
    quip: 'Thirty-one years at the end of the pier, darling. I AM the end.',
  ),
  UnitDef(
    id: 'gullivan',
    name: 'Saint Gullivan',
    tier: Tier.mythic,
    tags: ['Birds'],
    color: 0xFFFFFFFF,
    shape: Shape.triangle,
    mono: 'SG',
    dmg: 160,
    interval: 0.25,
    range: 3.0,
    perBird: 0.06,
    desc: 'Machine-gun pecks. +6% damage for every bird on your board.',
    quip: 'Blessed are the chip-takers.',
  ),
];

final Map<String, UnitDef> kUnitById = {for (final u in kUnits) u.id: u};

List<UnitDef> unitsOfTier(Tier t) => kUnits.where((u) => u.tier == t).toList();

/// Mythic recipes: one of each ingredient anywhere on your board.
const Map<String, List<String>> kRecipes = {
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
  });
}

const List<EnemyDef> kEnemies = [
  EnemyDef(
    'drip',
    'Drip',
    color: 0xFF4FB286,
    blurb: 'A puddle with ambitions.',
  ),
  EnemyDef(
    'pinchy',
    'Pinchy',
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
    'Slick Eel',
    hpMult: 0.6,
    speed: 1.9,
    color: 0xFF3F7CE8,
    body: 2,
    size: 0.28,
    blurb: 'Fast. Slippery. Smug.',
  ),
  EnemyDef(
    'wobbler',
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
    'Wibble',
    hpMult: 0.3,
    speed: 1.3,
    color: 0xFFE7B3FF,
    body: 3,
    size: 0.2,
    blurb: 'Half a Wobbler. Twice the attitude.',
  ),
  EnemyDef(
    'nanny',
    'Kelp Nanny',
    hpMult: 1.6,
    speed: 0.8,
    healAura: 0.03,
    color: 0xFF2E8B57,
    body: 4,
    size: 0.36,
    blurb: 'Heals nearby sea things 3% a second. Kill her first.',
  ),
  EnemyDef(
    'mist',
    'Sea Mist',
    hpMult: 0.8,
    speed: 1.2,
    evade: 0.35,
    color: 0xFFB8C7D9,
    body: 5,
    blurb: 'Dodges 35% of hits.',
  ),
  EnemyDef(
    'pollock',
    'Lucky Pollock',
    hpMult: 2.0,
    speed: 2.4,
    color: 0xFFFFD34D,
    body: 2,
    size: 0.3,
    blurb: 'Rare. Kill it within one lap for a tea leaf and 15 pennies.',
  ),
  EnemyDef(
    'bigdrip',
    'Big Drip',
    hpMult: 8,
    speed: 0.7,
    color: 0xFF1F8A5C,
    body: 0,
    size: 0.5,
    blurb: 'Every fifth wave. A lot of drip.',
  ),
  EnemyDef(
    'bailiff',
    'Bailiff',
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
    'Chip Dart',
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
    'Barnacle Bob',
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
    'Spinstar',
    hpMult: 0.75,
    speed: 2.0,
    color: 0xFFF07A8A,
    body: 2,
    size: 0.28,
    blurb: 'Spins down the boardwalk like a thrown plate.',
  ),
  EnemyDef(
    'hermit',
    'Tin Hermit',
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
    'Puffer',
    hpMult: 2.8,
    speed: 0.75,
    color: 0xFFF59B2B,
    body: 3,
    size: 0.36,
    blurb: 'Swells up to soak hits. Lots of health.',
  ),
  EnemyDef(
    'octo',
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
    'Lampjaw',
    hpMult: 1.7,
    speed: 0.9,
    healAura: 0.025,
    color: 0xFF2D5C8A,
    body: 4,
    size: 0.34,
    blurb: 'Its lamp heals nearby sea things 2.5% a second.',
  ),
  EnemyDef(
    'voidling',
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

/// Ordinary sea things (not bosses) have this much more health than
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

/// Ordinary enemies spawned in a wave.
int spawnCount(int wave) => 16 + (wave ~/ 3);

/// Which enemy types can appear on [wave] of [level]. Every level brings its
/// own regulars, and later levels bring them in sooner.
List<String> enemyPool(int wave, [int level = 1]) {
  final p = <String>['drip', 'drip'];
  if (wave >= 3) p.add('eel');
  if (wave >= 6) p.add('pinchy');
  if (wave >= 8) p.add('wobbler');
  if (wave >= 12) p.add('mist');
  if (wave >= 14) p.add('nanny');
  if (wave >= 18) p.add('flyer');
  if (wave >= 22) p.addAll(['pinchy', 'mist']);
  if (wave >= 26) p.add('barnacle');
  if (wave >= 32) p.add('star');
  if (wave >= 38) p.add('hermit');
  final theme = (level - 1) % kLevels.length;
  final early = level > 1 ? 4 : 0;
  if (theme == 1) {
    // Fogbank Arcade: things that puff, dodge and glow.
    if (wave >= 10 - early) p.add('octo');
    if (wave >= 16 - early) p.add('puffer');
    if (wave >= 24 - early) p.addAll(['angler', 'mist']);
  } else if (theme == 2) {
    // Crab Cove: shells everywhere.
    if (wave >= 8 - early) p.addAll(['hermit', 'pinchy']);
    if (wave >= 16 - early) p.add('barnacle');
    if (wave >= 28 - early) p.addAll(['hermit', 'star']);
  } else if (theme == 3) {
    // The Void Pier: things that should not be here.
    if (wave >= 6 - early) p.add('voidling');
    if (wave >= 18 - early) p.addAll(['voidling', 'angler']);
    if (wave >= 30 - early) p.addAll(['octo', 'puffer', 'flyer']);
  } else if (level > 1) {
    if (wave >= 20) p.addAll(['puffer', 'voidling']);
  }
  return p;
}

bool isBossWave(int wave) => wave % 10 == 0;
bool isMiniBossWave(int wave) => wave % 10 == 5;

// ---------------- Bosses ----------------
enum BossMech { brood, inspector, undertow, landlord }

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
    entrance: 'My babies. Go and play on the nice pier.',
    defeat: 'Mind... the... wet... floor...',
    mechText: 'Spawns three Drips every 6 seconds.',
  ),
  BossDef(
    'inspector',
    'The Pier Inspector',
    'Grimley Borough Council',
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
    entrance: 'Lovely little pier. Shame about the rent.',
    defeat: 'You can keep the pier. It is falling into the sea anyway.',
    mechText: 'Takes 15% of your pennies each lap. Shields and calls Bailiffs at 66% and 33%.',
  ),
  BossDef(
    'cuttle',
    'Captain Cuttle',
    'Terror of the Arcade',
    BossMech.undertow,
    hpMult: 11,
    speed: 0.6,
    armor: 0.1,
    color: 0xFFD9822B,
    entrance: 'Arr. This pier be mine now. All of it. Even the toilets.',
    defeat: 'Abandon... pier...',
    mechText: 'Every 9s vanishes in a cloud of ink for 2.5s: untargetable, heals 4%, then charges.',
  ),
  BossDef(
    'kingcrab',
    'King Crabbington',
    'Lord of the Cove',
    BossMech.inspector,
    hpMult: 12,
    speed: 0.5,
    armor: 0.3,
    color: 0xFFC0392B,
    entrance: 'Kneel. Or at least shuffle sideways respectfully.',
    defeat: 'Long live... me...',
    mechText: 'Every 7s pinches your strongest cell shut for 4s. Immune to stun and slow. Heavily armoured.',
  ),
  BossDef(
    'void',
    'The Void',
    'What Was Under the Pier',
    BossMech.brood,
    hpMult: 13,
    speed: 0.5,
    armor: 0.15,
    color: 0xFF6A3FD9,
    spawn: 'voidling',
    entrance: '...',
    defeat: '...oh.',
    mechText: 'Spawns three Voidlings every 6 seconds.',
  ),
];

final Map<String, BossDef> kBossById = {for (final b in kBosses) b.id: b};

// ---------------- Levels ----------------
class LevelDef {
  final String name;
  final String blurb;
  final String finalBoss;
  final double hpMult;
  const LevelDef(this.name, this.blurb, this.finalBoss, this.hpMult);
}

/// The first four levels. After that they come round again, harder each time.
const List<LevelDef> kLevels = [
  LevelDef(
    'Grimley Pier',
    'Last night of the season. Something is climbing out of the sea.',
    'landlord',
    1.0,
  ),
  LevelDef(
    'Fogbank Arcade',
    'The fog has come in, and so has a pirate.',
    'cuttle',
    1.35,
  ),
  LevelDef(
    'Crab Cove',
    'Shells, claws and a crab who thinks he is royalty.',
    'kingcrab',
    1.75,
  ),
  LevelDef(
    'The Void Pier',
    'The end of the pier is not where it used to be.',
    'void',
    2.3,
  ),
];

/// Level [n], counting from 1. Past the last one the list repeats and every
/// lap of it is 1.6 times tougher.
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

/// The boss on a boss wave of [level]. The level's own final boss waits for
/// wave [kFinalWave] (and every 50th wave of Endless); the others take turns
/// before it.
BossDef bossForWave(int wave, [int level = 1]) {
  final lv = levelDef(level);
  if (wave % kFinalWave == 0) return kBossById[lv.finalBoss]!;
  final mids = <String>[
    'brine',
    'inspector',
    'undertow',
    'landlord',
    'cuttle',
    'kingcrab',
  ];
  final idx = (level - 1) % kLevels.length;
  final pool = mids
      .where(
        (id) =>
            id != lv.finalBoss &&
            (idx >= 1 || id != 'cuttle') &&
            (idx >= 2 || id != 'kingcrab'),
      )
      .toList();
  if (idx == 0) pool.remove('landlord');
  final slot = ((wave % kFinalWave) ~/ 10) - 1;
  return kBossById[pool[(slot + (level - 1)) % pool.length]]!;
}

// ---------------- Partner ----------------
const String kPartnerName = 'Brenda';
const List<String> kBrendaLines = [
  'I have worked this pier for twenty years and I have never seen a crab that angry.',
  'Feed the machine, love. The machine is hungry.',
  'If we survive this I am asking for a raise. A small one. A biscuit.',
  'Three of the same? Squash \'em. That is what my mother did.',
  'Do not look the Inspector in the eye. He feeds on eye contact.',
  'I put a penny in for you. Do not tell the manager.',
  'They keep going round. Like my ex-husband.',
  'That one is wearing a tiny hat. Shoot the hat.',
];
