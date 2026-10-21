part of 'sim.dart';

/// What a cell gets from its bonds this tick.
class BondMod {
  double dmg = 0, spd = 0, range = 0, crit = 0, boss = 0, penny = 0;
  void add(BondDef b, double k) {
    dmg += b.dmg * k;
    spd += b.spd * k;
    range += b.range * k;
    crit += b.crit * k;
    boss += b.boss * k;
    penny += b.penny * k;
  }
}

/// A bond switched on between cells [i] and [j] of one board.
class ActiveBond {
  final int i, j;
  final BondDef def;

  /// 2 when a Matchmaker is next to either cell, else 1.
  final double k;
  const ActiveBond(this.i, this.j, this.def, [this.k = 1]);
}

extension HouseRulesOnGame on Game {
  /// Work out which bonds are on for [p]. Called every tick before attacks
  /// (and by the UI), so it always matches the board.
  void refreshBonds(PlayerSide p) {
    final out = <ActiveBond>[];
    final mods = List<BondMod?>.filled(p.cells.length, null);
    for (var i = 0; i < p.cells.length; i++) {
      final a = p.cells[i];
      if (a.isEmpty || !_cellWorks(a)) continue;
      final bonds = kBondsByUnit[a.def!.id];
      if (bonds == null) continue;
      for (var j = i + 1; j < p.cells.length; j++) {
        if (!cellsTouch(i, j)) continue;
        final b = p.cells[j];
        if (b.isEmpty || !_cellWorks(b)) continue;
        for (final bd in bonds) {
          if (bd.other(a.def!.id) != b.def!.id || bd.a == bd.b) continue;
          final k = (_nextToMatchmaker(p, i) || _nextToMatchmaker(p, j))
              ? 2.0
              : 1.0;
          out.add(ActiveBond(i, j, bd, k));
          (mods[i] ??= BondMod()).add(bd, k);
          (mods[j] ??= BondMod()).add(bd, k);
        }
      }
    }
    if (bondsCut > 0) {
      p.bonds = const [];
      p.bondMods = List<BondMod?>.filled(p.cells.length, null);
      p.bondsWaiting = out;
      return;
    }
    p.bonds = out;
    p.bondsWaiting = const [];
    p.bondMods = mods;
  }

  bool _nextToMatchmaker(PlayerSide p, int i) {
    for (var j = 0; j < p.cells.length; j++) {
      final c = p.cells[j];
      if (c.def?.abil == Abil.matchmaker && cellsTouch(i, j) && _cellWorks(c)) {
        return true;
      }
    }
    return false;
  }

  /// True while something on the field switches the Hoard bonus off.
  bool get hoardBlocked =>
      enemies.any((e) => !e.dead && e.trait == Trait.leech) ||
      bossList.any((b) => !b.dead && b.boss?.mech == BossMech.auditor);

  /// Extra damage from the Hoard rule for [p] right now (0.0 to 0.10).
  double hoardBonus(PlayerSide p) =>
      hoardBlocked ? 0 : hoardTier(p.pennies) * kHoardPct;

  /// Interest, clean sweep: paid as a wave starts.
  void payWaveRules() {
    final out = enemies.where((e) => !e.dead && !e.isBoss).length;
    final sweep = wave > 1 && out <= kCleanSweepMax;
    for (final p in sides) {
      final interest = interestFor(p.pennies);
      final extra = interest + (sweep ? kCleanSweepPay : 0);
      if (extra <= 0) continue;
      p.pennies += extra;
      p.stats.pennyEarned += extra;
      p.interestPaid += interest;
      if (sweep) p.sweeps++;
      if (p.index == 0) {
        final c = field.cellCenter(0, kBoardCols + kBoardCols ~/ 2);
        fx.add(
          Fx(
            FxType.text,
            x: c.x,
            y: c.y - 0.6,
            text: sweep ? 'CLEAN SWEEP +$extra' : 'INTEREST +$interest',
            color: 0xFFFFD166,
            size: 0.9,
          ),
        );
      }
    }
  }

  /// Quick kill: paid when the last boss of a wave goes down.
  void payQuickKill() {
    if (bossTimer < kBossSeconds * kQuickKillShare) return;
    for (final p in sides) {
      p.pennies += kQuickKillPay;
      p.stats.pennyEarned += kQuickKillPay;
      p.quickKills++;
    }
    final c = field.cellCenter(0, kBoardCols + kBoardCols ~/ 2);
    fx.add(
      Fx(
        FxType.text,
        x: c.x,
        y: c.y - 0.6,
        text: 'QUICK KILL +$kQuickKillPay',
        color: 0xFFFFD166,
        size: 1.1,
      ),
    );
    say('The Rift', 'Quick kill. $kQuickKillPay pennies each.');
  }

  /// Attack-speed bonus for a full stack (three of a kind) in [c].
  double fullStackBonus(Cell c) =>
      c.units.length >= kStackMax ? kFullStackSpeed : 0;

  /// Bond bonus on cell [ci] of [p], if any.
  BondMod? bondAt(PlayerSide p, int ci) =>
      ci >= 0 && ci < p.bondMods.length ? p.bondMods[ci] : null;

  /// The best penny-drop chance among [p]'s cells holding [d].
  double bondPennyFor(PlayerSide p, UnitDef d) {
    var best = 0.0;
    for (var i = 0; i < p.cells.length; i++) {
      if (p.cells[i].def?.id != d.id) continue;
      final m = p.bondMods[i];
      if (m != null && m.penny > best) best = m.penny;
    }
    return best;
  }
}

/// Bonds by figurine id, for quick lookups.
final Map<String, List<BondDef>> kBondsByUnit = () {
  final m = <String, List<BondDef>>{};
  for (final b in kBonds) {
    (m[b.a] ??= []).add(b);
    (m[b.b] ??= []).add(b);
  }
  return m;
}();
