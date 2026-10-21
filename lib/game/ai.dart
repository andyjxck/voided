// Brenda, the AI partner. Also drives the balance sims (playing your side).

import 'data.dart';
import 'sim.dart';

class Bot {
  final Game g;
  final PlayerSide p;
  final double thinkEvery;

  /// 0..1: how sharp the bot is. Brenda is a bit slower than a keen player.
  final double skill;
  double _t = 0;
  double _chatT = 25;
  int _line = 0;
  final bool chatty;

  Bot(
    this.g,
    this.p, {
    this.thinkEvery = 0.6,
    this.skill = 1.0,
    this.chatty = false,
  });

  void update(double dt) {
    _t -= dt;
    if (chatty) {
      _chatT -= dt;
      if (_chatT <= 0) {
        _chatT = 38 + g.rng.nextDouble() * 30;
        g.say(kPartnerName, kBrendaLines[_line++ % kBrendaLines.length]);
      }
    }
    if (_t > 0) return;
    _t = thinkEvery;
    act();
  }

  /// One round of decisions. Returns how many actions were taken.
  int act() {
    var n = 0;
    // 1. Mythic recipes first.
    for (final m in kRecipes.keys) {
      if (g.canCraft(p, m)) {
        g.craft(p, m);
        n++;
      }
    }
    // 2. Merges, keeping recipe ingredients we might need.
    for (var i = 0; i < p.cells.length; i++) {
      if (g.canMerge(p, i)) {
        g.merge(p, i);
        n++;
      }
    }
    // 3. Gamble tea leaves.
    while (p.leaves >= 1 && p.hasEmptyCell) {
      final opt = p.leaves >= 2 && g.wave >= 25
          ? kGambles[2]
          : (g.wave >= 12 ? kGambles[1] : kGambles[0]);
      if (p.leaves < opt.cost) break;
      g.gamble(p, opt);
      n++;
    }
    // 4. Upgrades vs summons: buy whichever adds more damage per penny.
    var guard = 0;
    while (guard++ < 40) {
      final cost = g.summonCost(p);
      final gi = _upgradeFocus();
      final upCost = upgradeCost(gi, p.upg[gi]);
      final groupDps = _groupDps(gi);
      final upValue = p.upg[gi] >= kMaxUpgrade
          ? 0.0
          : groupDps * kUpgradeStep / (1 + kUpgradeStep * p.upg[gi]) / upCost;
      // A summon is worth its average figurine plus the merges it feeds.
      final sumValue =
          (p.hasEmptyCell ? 26.0 * (1 + kUpgradeStep * p.upg[0]) : 0.0) /
          cost *
          (0.8 + 0.4 * skill);
      if (p.luck < kMaxLuck &&
          g.wave >= 8 + p.luck * 6 &&
          p.pennies >= luckUpgradeCost(p.luck) + cost) {
        g.upgradeLuck(p);
        n++;
        continue;
      }
      if (upValue > sumValue) {
        if (p.pennies >= upCost) {
          g.upgrade(p, gi);
          n++;
          continue;
        }
        break; // save up
      }
      if (p.pennies >= cost) {
        if (!p.hasEmptyCell && !_makeRoom()) break;
        if (g.summon(p).ok) {
          n++;
          continue;
        }
      }
      break;
    }
    return n;
  }

  double _groupDps(int gi) {
    var d = 0.0;
    for (final u in p.allUnits) {
      if (upgradeGroup(u.def.tier) == gi) d += u.def.dps;
    }
    return d;
  }

  int _upgradeFocus() {
    // Spend where the damage is.
    final dps = [0.0, 0.0, 0.0];
    for (final u in p.allUnits) {
      dps[upgradeGroup(u.def.tier)] += u.def.dps;
    }
    var best = 0;
    for (var i = 1; i < 3; i++) {
      if (dps[i] > dps[best]) best = i;
    }
    return best;
  }

  /// Sell a lone common that is not a recipe ingredient.
  bool _makeRoom() {
    final needed = {for (final r in kRecipes.values) ...r};
    int? pick;
    for (var i = 0; i < p.cells.length; i++) {
      final c = p.cells[i];
      if (c.isEmpty || c.def!.tier != Tier.common) continue;
      if (needed.contains(c.def!.id) && p.countOf(c.def!.id) <= 1) continue;
      if (pick == null || c.units.length < p.cells[pick].units.length) pick = i;
    }
    if (pick == null) return false;
    g.sell(p, pick);
    return true;
  }
}
