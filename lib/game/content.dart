part of 'data.dart';

// The content plan: 18 new figurines (one new union, Lamp), 8 new Mythic
// recipes, the new enemy traits and the six-level campaign.

/// A figurine's special move, on top of its plain attack.
enum Abil {
  none,

  /// Bonds touching this cell count double.
  matchmaker,

  /// Every [abilEvery]s collects a penny for every 3 riftlings in range, up
  /// to [abilPow].
  toll,

  /// Reveals hidden enemies in range for every figurine.
  reveal,

  /// Every [UnitDef.abilEvery]s, neighbouring cells are immune to silence,
  /// condemn, lock and grabs for [UnitDef.abilDur]s.
  band,

  /// Hits are sticky: no blinking, diving, ramming or teleporting.
  sticky,

  /// Every [UnitDef.abilEvery]th hit shatters shields and shells.
  shatter,

  /// Lights the lane in range: no dodging, no hiding, +[abilPow] damage taken.
  lighter,

  /// Every [abilEvery]s pushes enemies in range back [abilPow] cells.
  horn,

  /// Every [abilEvery]s freezes a patch of lane for [abilDur]s.
  chime,

  /// A beam that ignores dodge, hiding and Null and ramps on one target.
  beam,

  /// Hits stop healing for [abilDur]s and mark for +[abilPow] damage.
  watch,

  /// Can hit diving, inked, tunnelled and submerged targets.
  diver,

  /// Mythic: the whole lane caramelises every [abilEvery]s.
  caramel,

  /// Mythic: lights the whole lane; figurines in its light deal more.
  beacon,

  /// Mythic: evicts the front non-boss enemies back to the start.
  evict,

  /// Mythic: a heavy ink shot that blinds (no healing or dodging).
  ink,

  /// Mythic: neighbours can't be disabled; pinches strip armour.
  crown,

  /// Mythic: a phantom train laps the lane and hits everything once.
  train,

  /// Mythic: copies the strongest neighbouring non-Mythic's attack.
  shadow,

  /// Mythic: erases the healthiest non-boss enemy in range.
  erase,
}

const List<String> kAllUnions = [
  'Birds',
  'Staff',
  'Sweets',
  'Arcade',
  'Sea',
  'Lamp',
];

/// The stronger rule each union gets with five different members.
const Map<String, String> kUnion5Rules = {
  'Birds': 'Birds attack 35% faster',
  'Staff': 'Staff hit 35% harder',
  'Sweets': 'Slowed enemies take 10% more damage',
  'Arcade': '+1 penny every 5 kills by Arcade',
  'Sea': 'Sea figurines get +1 range and hit submerged things',
  'Lamp': 'The whole lane is lit and Lamp figurines hit 20% harder',
};

const List<UnitDef> kUnitsNew = [
  UnitDef(
    id: 'lil',
    name: 'Riftwick Lil',
    tier: Tier.common,
    tags: ['Lamp'],
    color: 0xFFFFD27A,
    shape: Shape.drop,
    mono: 'Li',
    dmg: 7,
    interval: 0.9,
    range: 2.6,
    abil: Abil.reveal,
    desc:
        'A small lantern. Shows hidden things in range so everyone can hit them. Lamp hits never miss.',
    quip: 'I am not scared of the dark. The Rift is scared of me. Mostly.',
  ),
  UnitDef(
    id: 'bandsman',
    name: 'The Rift Bandsman',
    tier: Tier.rare,
    tags: ['Staff'],
    color: 0xFFC8553D,
    shape: Shape.hexagon,
    mono: 'Bb',
    dmg: 18,
    interval: 1.0,
    range: 2.4,
    splash: 0.6,
    abil: Abil.band,
    abilEvery: 6,
    abilDur: 3,
    desc:
        'Every 6s the band strikes up: cells next to him can\'t be silenced, condemned, locked or grabbed for 3s.',
    quip: 'Oom-pah. OOM-PAH. Louder than the Rift.',
  ),
  UnitDef(
    id: 'mouse',
    name: 'Sugar Riftmouse',
    tier: Tier.rare,
    tags: ['Sweets'],
    color: 0xFFF7A1C4,
    shape: Shape.circle,
    mono: 'Sm',
    dmg: 16,
    interval: 0.8,
    range: 2.5,
    slowPct: 0.15,
    slowDur: 1.0,
    abil: Abil.sticky,
    abilDur: 2,
    desc:
        'Sticky hits: for 2s the target can\'t blink, dive, ram or teleport.',
    quip: 'Squeak. That means "you are stuck on this side now".',
  ),
  UnitDef(
    id: 'tess',
    name: 'Shatter Hammer Tess',
    tier: Tier.epic,
    tags: ['Sweets'],
    color: 0xFFB5651D,
    shape: Shape.square,
    mono: 'Te',
    dmg: 62,
    interval: 1.2,
    range: 2.2,
    slowPct: 0.3,
    slowDur: 1.5,
    abil: Abil.shatter,
    abilEvery: 5,
    desc:
        'Every 5th hit shatters shields and shells outright, and slows. Hollow Hermits, Rift Clams and the Landlord hate her.',
    quip: 'Hard toffee. Harder hammer. The Rift is just a big crack.',
  ),
  UnitDef(
    id: 'lamplighter',
    name: 'The Riftlighter',
    tier: Tier.epic,
    tags: ['Lamp'],
    color: 0xFFFFB347,
    shape: Shape.triangle,
    mono: 'Ll',
    dmg: 46,
    interval: 1.0,
    range: 3.0,
    abil: Abil.lighter,
    abilPow: 0.10,
    desc:
        'Lights the lane in range. Enemies there can\'t dodge or hide and take 10% more damage.',
    quip: 'Every lamp along the Rift, lit by hand. Every one.',
  ),
  UnitDef(
    id: 'hale',
    name: 'Riftmaster Hale',
    tier: Tier.epic,
    tags: ['Sea'],
    color: 0xFF3D5A80,
    shape: Shape.shield,
    mono: 'Ha',
    dmg: 56,
    interval: 1.1,
    range: 2.8,
    abil: Abil.horn,
    abilEvery: 4,
    abilPow: 0.6,
    desc:
        'Every 4s his horn pushes everything in range back 0.6 cells (bosses 0.2).',
    quip: 'Back. BACK. This is a Rift, not a holiday.',
  ),
  UnitDef(
    id: 'icecream',
    name: 'The Void Ice Cream Man',
    tier: Tier.legendary,
    tags: ['Sweets'],
    color: 0xFFBDE0FE,
    shape: Shape.star,
    mono: 'Ic',
    dmg: 165,
    interval: 1.0,
    range: 3.0,
    slowPct: 0.3,
    slowDur: 1.5,
    abil: Abil.chime,
    abilEvery: 6,
    abilDur: 1,
    desc:
        'Every 6s his chime freezes a patch of lane solid for 1s.',
    quip: 'Greensleeves, played slightly wrong, from the far side of the crack, forever.',
  ),
  UnitDef(
    id: 'elmo',
    name: 'Saint Riftfire',
    tier: Tier.legendary,
    tags: ['Lamp'],
    color: 0xFF9AD1F5,
    shape: Shape.diamond,
    mono: 'El',
    dmg: 105,
    interval: 0.5,
    range: 3.4,
    abil: Abil.beam,
    abilPow: 0.15,
    desc:
        'A beam that ignores dodging, hiding and Null, and burns 15% hotter for every second on the same target.',
    quip: 'Sailors used to pray for me. Now they just point at the crack.',
  ),
  UnitDef(
    id: 'watchman',
    name: 'The Rift Watchman',
    tier: Tier.legendary,
    tags: ['Staff'],
    color: 0xFF6C757D,
    shape: Shape.shield,
    mono: 'Wa',
    dmg: 195,
    interval: 1.0,
    range: 3.0,
    abil: Abil.watch,
    abilDur: 4,
    abilPow: 0.15,
    desc:
        'His hits stop healing for 4s and mark the target to take 15% more damage.',
    quip: 'Twelve o\'clock, the Rift is open, and all is NOT well.',
  ),
  UnitDef(
    id: 'diver',
    name: 'The Rift Diver',
    tier: Tier.legendary,
    tags: ['Sea'],
    color: 0xFFB08D57,
    shape: Shape.circle,
    mono: 'Pd',
    dmg: 150,
    interval: 1.1,
    range: 3.2,
    multi: 2,
    abil: Abil.diver,
    desc:
        'Hits diving, inked, tunnelled and submerged things. The Undertow, the Ghost Train\'s tunnel and Wrecker\'s Ghosts.',
    quip: 'Holding my breath since 1952. The Rift goes deeper than the sea.',
  ),
  // ---- Mythics ----
  UnitDef(
    id: 'confectioner',
    name: 'The Void Confectioner',
    tier: Tier.mythic,
    tags: ['Sweets'],
    color: 0xFFFFA62B,
    shape: Shape.star,
    mono: 'Cf',
    dmg: 400,
    interval: 0.9,
    range: 3.2,
    splash: 1.0,
    slowPct: 0.35,
    slowDur: 2,
    abil: Abil.caramel,
    abilEvery: 10,
    abilDur: 2,
    desc:
        'Every 10s the lane caramelises: everything is stuck for 2s, sticky, and loses its shell.',
    quip: 'Boiling point. Hard crack. Rift crack. Everybody stay still.',
  ),
  UnitDef(
    id: 'beacon',
    name: 'The Rift Beacon',
    tier: Tier.mythic,
    tags: ['Lamp'],
    color: 0xFFFFE066,
    shape: Shape.star,
    mono: 'Be',
    dmg: 380,
    interval: 0.9,
    range: 3.6,
    multi: 2,
    abil: Abil.beacon,
    abilPow: 0.2,
    desc:
        'Lights the whole lane so nothing can hide or dodge. Figurines in its light deal 20% more damage.',
    quip: 'Lights on. Everyone. Look at me, not the crack.',
  ),
  UnitDef(
    id: 'freeholder',
    name: 'The Rift Freeholder',
    tier: Tier.mythic,
    tags: ['Arcade'],
    color: 0xFF8E44AD,
    shape: Shape.diamond,
    mono: 'Fh',
    dmg: 420,
    interval: 0.9,
    range: 3.2,
    killPennies: 2,
    abil: Abil.evict,
    abilEvery: 12,
    abilPow: 3,
    desc:
        'Every 12s evicts the three front non-boss enemies back to the start of the lane.',
    quip: 'I own the Rift now. And you are all trespassing.',
  ),
  UnitDef(
    id: 'cannon',
    name: 'Cuttle\'s Rift Cannon',
    tier: Tier.mythic,
    tags: ['Sea'],
    color: 0xFF2E4057,
    shape: Shape.hexagon,
    mono: 'Cc',
    dmg: 430,
    interval: 1.0,
    range: 3.4,
    splash: 1.0,
    abil: Abil.ink,
    abilEvery: 9,
    abilDur: 3,
    abilPow: 6,
    desc:
        'Every 9s a heavy ink shot splashes and blinds: no healing or dodging for 3s.',
    quip: 'The Captain sends his regards. And his ink, by way of the Rift.',
  ),
  UnitDef(
    id: 'crown',
    name: 'The Cracked Crown',
    tier: Tier.mythic,
    tags: ['Staff'],
    color: 0xFFD62828,
    shape: Shape.shield,
    mono: 'Cr',
    dmg: 470,
    interval: 0.9,
    range: 3.0,
    abil: Abil.crown,
    abilPow: 0.3,
    desc:
        'Neighbouring cells can\'t be silenced, locked or condemned. Its pinches strip 30% armour.',
    quip: 'Kneel. Sideways is fine. The crack goes sideways too.',
  ),
  UnitDef(
    id: 'lasttrain',
    name: 'The Last Train Through',
    tier: Tier.mythic,
    tags: ['Arcade'],
    color: 0xFF52B788,
    shape: Shape.square,
    mono: 'Lt',
    dmg: 300,
    interval: 0.8,
    range: 3.2,
    chain: 2,
    abil: Abil.train,
    abilEvery: 10,
    abilPow: 2,
    desc:
        'Every 10s a phantom train comes out of the Rift, laps the lane and hits everything once, one carriage per active union.',
    quip: 'All aboard. No, really, all of you. Next stop: the other side.',
  ),
  UnitDef(
    id: 'kshadow',
    name: 'The Lamp Keeper\'s Shadow',
    tier: Tier.mythic,
    tags: ['Lamp'],
    color: 0xFF3A0CA3,
    shape: Shape.triangle,
    mono: 'Ks',
    dmg: 340,
    interval: 0.9,
    range: 3.4,
    abil: Abil.shadow,
    abilPow: 1.5,
    desc:
        'Copies the attack of the strongest neighbouring non-Mythic at 150%.',
    quip: 'He kept the light on the Rift. I kept everything else.',
  ),
  UnitDef(
    id: 'nothing',
    name: 'The Nothing',
    tier: Tier.mythic,
    tags: kAllUnions,
    color: 0xFF7B2CBF,
    shape: Shape.circle,
    mono: '∅',
    dmg: 380,
    interval: 1.0,
    range: 3.4,
    abil: Abil.erase,
    abilEvery: 15,
    abilPow: 0.08,
    desc:
        'Counts toward every union. Every 15s erases the healthiest non-boss thing in range, or takes 8% of a boss\'s health.',
    quip: '...',
  ),
  // ---- Mythics added with bonds and house rules ----
  UnitDef(
    id: 'matchmaker',
    name: 'The Matchmaker',
    tier: Tier.mythic,
    tags: ['Arcade', 'Sweets'],
    color: 0xFFFF8FAB,
    shape: Shape.star,
    mono: 'Mm',
    dmg: 260,
    interval: 0.7,
    range: 3.0,
    multi: 2,
    abil: Abil.matchmaker,
    desc:
        'Bonds in the cells next to it count double. Fires two shards at a time.',
    quip: 'You two. Stand there. Closer. Lovely.',
  ),
  UnitDef(
    id: 'tollkeeper',
    name: 'The Tollkeeper',
    tier: Tier.mythic,
    tags: ['Arcade'],
    color: 0xFFC9A227,
    shape: Shape.hexagon,
    mono: 'Tk',
    dmg: 380,
    interval: 0.85,
    range: 3.0,
    pennyScale: 0.0015,
    abil: Abil.toll,
    abilEvery: 6,
    abilPow: 6,
    desc:
        'Every 6s takes a penny for every 3 riftlings in range, up to 6. Hits harder the more you hold.',
    quip: 'Nobody crosses free. Not even the dark.',
  ),
  UnitDef(
    id: 'murmuration',
    name: 'The Murmuration',
    tier: Tier.mythic,
    tags: ['Birds'],
    color: 0xFF6C757D,
    shape: Shape.triangle,
    mono: 'Mu',
    dmg: 70,
    interval: 0.5,
    range: 3.3,
    multi: 5,
    perBird: 0.06,
    desc:
        'Five strikes at once. Every Bird on your board adds 6% to its damage.',
    quip: 'One of us is a gull. All of us are the storm.',
  ),
  UnitDef(
    id: 'foreman',
    name: 'The Night Foreman',
    tier: Tier.mythic,
    tags: ['Staff'],
    color: 0xFF8D6E63,
    shape: Shape.shield,
    mono: 'Nf',
    dmg: 420,
    interval: 0.9,
    range: 2.8,
    stunChance: 0.12,
    stunDur: 0.6,
    auraTag: 'Staff',
    auraSpeed: 0.3,
    auraRange: 2.6,
    desc:
        'Staff within 2.6 cells work 30% faster. Its clipboard stuns 12% of the time.',
    quip: 'Clock in. Clock out. In between, hold the line.',
  ),
  UnitDef(
    id: 'pearl',
    name: 'Mother of Pearl',
    tier: Tier.mythic,
    tags: ['Sea'],
    color: 0xFFE9ECEF,
    shape: Shape.drop,
    mono: 'Mp',
    dmg: 560,
    interval: 1.1,
    range: 3.4,
    bossMult: 1.3,
    executePct: 0.12,
    desc:
        'Finishes off any riftling under 12% health. Deals 30% more to bosses.',
    quip: 'Grit becomes a pearl. You become grit.',
  ),
  UnitDef(
    id: 'choir',
    name: 'The Ember Choir',
    tier: Tier.mythic,
    tags: ['Lamp', 'Staff'],
    color: 0xFFF77F00,
    shape: Shape.circle,
    mono: 'Ec',
    dmg: 300,
    interval: 0.8,
    range: 3.0,
    chain: 5,
    burnDps: 90,
    burnDur: 3,
    desc:
        'Its song jumps between 5 riftlings and leaves each one burning for 3s.',
    quip: 'Sing up. The dark hates a harmony.',
  ),
];

const Map<String, List<String>> kRecipesNew = {
  'confectioner': ['icecream', 'tess', 'mouse'],
  'beacon': ['elmo', 'lamplighter', 'lil'],
  'freeholder': ['bertie', 'claw', 'thwack'],
  'cannon': ['diver', 'hale', 'rock'],
  'crown': ['watchman', 'sal', 'bandsman'],
  'lasttrain': ['vex', 'squall', 'lou'],
  'kshadow': ['keeper', 'lamplighter', 'admiral'],
  'nothing': ['albatross', 'icecream', 'elmo'],
  'matchmaker': ['icecream', 'claw', 'bandsman'],
  'tollkeeper': ['bertie', 'claw', 'dave'],
  'murmuration': ['albatross', 'squall', 'gull'],
  'foreman': ['watchman', 'lou', 'sal'],
  'pearl': ['diver', 'morag', 'lil'],
  'choir': ['elmo', 'lamplighter', 'carl'],
};

/// The six Echo Mythics: tamed final bosses, won by clearing each level.
const List<String> kEchoMythics = [
  'freeholder',
  'cannon',
  'crown',
  'lasttrain',
  'kshadow',
  'nothing',
];

// ---------------- Enemy traits ----------------
enum Trait {
  none,
  armor,
  split,
  dodge,
  heal,
  bonus,
  flying,
  ink,
  puff,
  thief,
  lure,
  heavy,
  spender,
  tin,
  pair,
  grow,
  shell,
  bruiser,
  castle,
  pony,
  mirror,
  ram,
  bigtop,
  moth,
  hidden,
  flash,
  foghorn,
  blink,
  nullify,
  echo,
  unmaker,
  hollow,
  husk,

  /// While alive, the Hoard rule gives nobody any damage.
  leech,

  /// Every [every]s shields riftlings within 1.5 cells for [pow] of their
  /// health.
  warden,

  /// Takes at most [pow] of its health from any one hit.
  cap,

  /// Gets back up once at [pow] health, unless the hit was area damage.
  revive,

  /// Riftlings within 1.5 cells move [pow] faster.
  drum,

  /// Every [every]s burrows for 1.5s: can't be hit, moves twice as fast.
  burrow,
}

/// Enemy types that disrupt your board or economy. At most two of these
/// types share a wave.
const Set<String> kDisruptive = {
  'thief',
  'angler',
  'spender',
  'dodgem',
  'moth',
  'lantern',
  'foghorn',
  'unmaker',
  'hollow',
  'bigtop',
  'castle',
};

const List<EnemyDef> kEnemiesNew = [
  EnemyDef(
    'thief',
    'Token Thief',
    hpMult: 0.9,
    speed: 1.3,
    trait: Trait.thief,
    threat: 2,
    color: 0xFF6B705C,
    body: 0,
    size: 0.3,
    blurb:
        'Steals 2 pennies each lap. Kill it and you get them back, plus one.',
  ),
  EnemyDef(
    'plushie',
    'Plushie Pile',
    hpMult: 2.5,
    speed: 0.55,
    trait: Trait.heavy,
    weight: 3,
    threat: 3,
    color: 0xFFC9A227,
    body: 1,
    size: 0.4,
    blurb: 'Three prizes stitched together. Counts as 3 toward the limit.',
  ),
  EnemyDef(
    'spender',
    'Big Spender',
    hpMult: 9,
    speed: 0.55,
    trait: Trait.spender,
    threat: 8,
    color: 0xFFB8860B,
    body: 1,
    size: 0.5,
    blurb:
        'Elite. While it lives, enemies get 5% faster for every 50 pennies you hold, up to 30%.',
  ),
  EnemyDef(
    'clam',
    'Rift Clam',
    hpMult: 1.1,
    speed: 0.9,
    trait: Trait.shell,
    pow: 6,
    threat: 2,
    color: 0xFF8D99AE,
    body: 1,
    size: 0.32,
    blurb: 'Its shell soaks up the first 6 hits, however big. Fast hitters.',
  ),
  EnemyDef(
    'bruiser',
    'Breach Crab',
    hpMult: 2.2,
    speed: 0.7,
    armor: 0.2,
    trait: Trait.bruiser,
    threat: 3,
    color: 0xFFA4161A,
    body: 1,
    size: 0.38,
    blurb:
        'Every slow, stun or freeze adds a stack. At three it shrugs off control for 6s.',
  ),
  EnemyDef(
    'castle',
    'Ash Castle',
    hpMult: 10,
    speed: 0.4,
    armor: 0.2,
    trait: Trait.castle,
    every: 6,
    weight: 5,
    threat: 8,
    color: 0xFFD4A373,
    body: 1,
    size: 0.55,
    blurb: 'Elite. Counts as 5 and lets out two Pinchies every 6s.',
  ),
  EnemyDef(
    'pony',
    'Hollow Pony',
    hpMult: 0.9,
    speed: 1.1,
    trait: Trait.pony,
    threat: 1,
    color: 0xFFF1E3D3,
    body: 0,
    size: 0.3,
    blurb: 'Comes in fours. Every pony that falls makes the rest 25% faster.',
  ),
  EnemyDef(
    'mirror',
    'Mirrorling',
    hpMult: 1.0,
    speed: 1.0,
    trait: Trait.mirror,
    threat: 2,
    color: 0xFFADE8F4,
    body: 2,
    size: 0.3,
    blurb:
        'Killed by a single-target hit, it splits into two copies at 30% health. Splash, chain and pulse kills leave nothing.',
  ),
  EnemyDef(
    'dodgem',
    'Phantom Dodgem',
    hpMult: 1.6,
    speed: 0.9,
    armor: 0.15,
    trait: Trait.ram,
    every: 5,
    threat: 3,
    color: 0xFFE63946,
    body: 1,
    size: 0.34,
    blurb:
        'Every 5s it rams forward, shoving everything nearby half a cell on. Stun or Sticky stops it.',
  ),
  EnemyDef(
    'bigtop',
    'The Big Top',
    hpMult: 9,
    speed: 0.5,
    trait: Trait.bigtop,
    weight: 3,
    threat: 8,
    color: 0xFFD00000,
    body: 1,
    size: 0.55,
    blurb: 'Elite. Counts as 3 and lets out two level enemies every lap.',
  ),
  EnemyDef(
    'moth',
    'Riftmoth',
    hpMult: 0.6,
    speed: 1.4,
    trait: Trait.moth,
    threat: 2,
    color: 0xFF9C8C74,
    body: 2,
    size: 0.26,
    blurb:
        'Flies at your strongest cell and silences it until killed. Never more than two at once.',
  ),
  EnemyDef(
    'ghost',
    'Wrecker\'s Ghost',
    hpMult: 1.2,
    speed: 1.0,
    trait: Trait.hidden,
    threat: 2,
    color: 0xFF95D5B2,
    body: 2,
    size: 0.32,
    blurb:
        'Hidden until a Lamp, the beam or a splash hit shows it for 3s. Watch for wet footprints.',
  ),
  EnemyDef(
    'lantern',
    'Void Lantern',
    hpMult: 1.3,
    speed: 0.9,
    trait: Trait.flash,
    threat: 2,
    color: 0xFF264653,
    body: 0,
    size: 0.32,
    blurb:
        'When it dies it flashes and halves the attack speed of the two nearest cells for 2s.',
  ),
  EnemyDef(
    'foghorn',
    'The Rift Horn',
    hpMult: 9,
    speed: 0.5,
    armor: 0.15,
    trait: Trait.foghorn,
    every: 10,
    threat: 8,
    color: 0xFF8D6E63,
    body: 1,
    size: 0.55,
    blurb:
        'Elite. Every 10s it blasts away slows, stuns and freezes, and everything is immune for 3s.',
  ),
  EnemyDef(
    'null',
    'Null',
    hpMult: 1.3,
    speed: 0.95,
    trait: Trait.nullify,
    threat: 2,
    color: 0xFF111111,
    body: 2,
    size: 0.32,
    blurb: 'Immune to every status: slow, stun, freeze, burn and curse.',
  ),
  EnemyDef(
    'echo',
    'Echo',
    hpMult: 1.1,
    speed: 1.0,
    trait: Trait.echo,
    threat: 2,
    color: 0xFF9D4EDD,
    body: 2,
    size: 0.3,
    blurb:
        'Copies the trait of the thing just ahead of it: armour, dodge, heal or shell.',
  ),
  EnemyDef(
    'unmaker',
    'Unmaker',
    hpMult: 1.8,
    speed: 0.8,
    trait: Trait.unmaker,
    threat: 4,
    color: 0xFF5A189A,
    body: 2,
    size: 0.36,
    blurb:
        'If it finishes a lap it erases your lowest figurine, Commons first. At most one a wave.',
  ),
  EnemyDef(
    'hollow',
    'The Hollow',
    hpMult: 9,
    speed: 0.5,
    trait: Trait.hollow,
    threat: 8,
    color: 0xFF3C096C,
    body: 2,
    size: 0.55,
    blurb:
        'Elite. Shares damage evenly with every non-boss enemy within 2 cells. Splash hits the whole group.',
  ),
  EnemyDef(
    'clown',
    'Cracked Clown',
    hpMult: 0.35,
    speed: 1.8,
    threat: 1,
    color: 0xFFFF595E,
    body: 0,
    size: 0.24,
    blurb: 'A Ringmaster act. Fast, weak, and there are six of them.',
  ),
  EnemyDef(
    'lion',
    'Rift Lion',
    hpMult: 4,
    speed: 0.8,
    armor: 0.45,
    trait: Trait.armor,
    threat: 4,
    color: 0xFFE09F3E,
    body: 1,
    size: 0.42,
    blurb: 'A Ringmaster act. One armoured brute. Curse it.',
  ),
  EnemyDef(
    'husk',
    'Shell Husk',
    hpMult: 6,
    speed: 0.45,
    armor: 0.5,
    trait: Trait.husk,
    weight: 10,
    threat: 0,
    color: 0xFFBC4749,
    body: 1,
    size: 0.5,
    blurb:
        'King Crabbington\'s empty shell. Counts as 10 toward the limit. Curse it.',
  ),
  EnemyDef(
    'carriage',
    'Ghost Carriage',
    hpMult: 1,
    speed: 1,
    threat: 0,
    color: 0xFF2D6A4F,
    body: 1,
    size: 0.4,
    blurb: 'Part of the Ghost Train.',
  ),
];

// ---------------- Campaign ----------------
enum LevelRule { none, fog, tide, rides, beam, statik }

extension LevelRuleInfo on LevelRule {
  String get label => const [
    'No rule',
    'Fog',
    'Tide',
    'Rides',
    'The Beam',
    'Static',
  ][index];
  String get text => const [
    'No level rule. Every basic trick, one at a time.',
    'Every few waves fog covers a third of the lane for 8s. Things in it dodge 20% more and can only be hit from 3 cells away. Lamp figurines and chains cut through.',
    'Waves alternate high and low tide. At high tide things on the waterline half move 15% faster, at low tide 15% slower.',
    'Two stretches of lane are ride tracks. Things on them move 30% faster and bunch up. Splash at the exits.',
    'A lighthouse beam sweeps the board every 10s: figurines in it attack 20% faster for 3s. Hidden things in the dark can only be hit by Lamp figurines or when lit.',
    'Every 10 waves one cell starts to flicker for 10 waves: figurines on it attack 25% slower. Never more than two at once.',
  ][index];
}

/// Which enemy each level brings, and the wave it first turns up. A type's
/// first wave is a showcase: it comes alone with Seeps.
const Map<int, Map<String, int>> kLevelRoster = {
  1: {
    'drip': 1,
    'eel': 3,
    'pinchy': 6,
    'wobbler': 8,
    'mist': 12,
    'nanny': 14,
    'flyer': 18,
  },
  2: {
    'drip': 1,
    'eel': 1,
    'pinchy': 2,
    'octo': 3,
    'wobbler': 5,
    'mist': 6,
    'puffer': 8,
    'thief': 12,
    'angler': 16,
    'plushie': 22,
  },
  3: {
    'drip': 1,
    'pinchy': 1,
    'hermit': 3,
    'eel': 4,
    'nanny': 6,
    'star': 8,
    'flyer': 10,
    'barnacle': 12,
    'clam': 16,
    'bruiser': 24,
  },
  4: {
    'drip': 1,
    'wobbler': 1,
    'pony': 3,
    'pinchy': 4,
    'star': 5,
    'octo': 6,
    'puffer': 8,
    'mirror': 10,
    'dodgem': 18,
  },
  5: {
    'drip': 1,
    'mist': 1,
    'moth': 3,
    'flyer': 4,
    'octo': 5,
    'angler': 7,
    'ghost': 10,
    'mirror': 12,
    'lantern': 18,
  },
  6: {
    'drip': 1,
    'pinchy': 1,
    'voidling': 3,
    'mist': 4,
    'nanny': 5,
    'thief': 6,
    'null': 8,
    'clam': 10,
    'pony': 11,
    'echo': 14,
    'moth': 16,
    'unmaker': 22,
  },
};

/// Each level's elite, on waves 5, 15, 25, 35 and 45.
const Map<int, String> kLevelElite = {
  1: 'bigdrip',
  2: 'spender',
  3: 'castle',
  4: 'bigtop',
  5: 'foghorn',
  6: 'hollow',
};

/// Authored squads, added on top of the threat budget once every member is
/// in the level's roster.
const List<List<String>> kSquads = [
  ['pinchy', 'pinchy', 'pinchy', 'nanny'], // shield wall
  ['wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble', 'wibble'], // swarm
  ['drip', 'drip', 'ghost', 'drip', 'ghost'], // ambush
  ['pony', 'pony', 'pony', 'pony'], // carousel
  ['star', 'star'], // a tethered pair
  ['moth', 'moth', 'moth'], // a flight of moths
  ['hermit', 'hermit', 'nanny'],
  ['mirror', 'mirror', 'octo'],
  ['null', 'echo', 'null'],
  ['clam', 'clam', 'eel', 'eel'],
];
