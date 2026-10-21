import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/sim.dart';

const Color kBondGold = Color(0xFFE3B451);

/// Union members on [p]'s board, by union.
Map<String, Set<String>> unionMembers(PlayerSide p) {
  final byTag = <String, Set<String>>{};
  for (final u in p.allUnits) {
    for (final t in u.def.tags) {
      (byTag[t] ??= <String>{}).add(u.def.id);
    }
  }
  return byTag;
}

/// Lines for the cell pop-up: bonds this cell has on, then ones it could
/// make with a neighbour.
List<(String, bool)> bondLines(Game g, PlayerSide p, int ci) {
  final c = p.cells[ci];
  if (c.isEmpty) return const [];
  g.refreshBonds(p);
  final out = <(String, bool)>[];
  final active = <BondDef>{};
  for (final b in [...p.bonds, ...p.bondsWaiting]) {
    if (b.i != ci && b.j != ci) continue;
    active.add(b.def);
    final other = kUnitById[b.def.other(c.def!.id)]?.name ?? '';
    out.add((
      '${b.def.name} with $other${b.k > 1 ? ' (x2)' : ''}: ${b.def.effect}',
      true,
    ));
  }
  for (final b in bondsOf(c.def!.id)) {
    if (active.contains(b)) continue;
    final other = kUnitById[b.other(c.def!.id)]?.name ?? '';
    out.add(('Bonds with $other next to it: ${b.effect}', false));
  }
  return out;
}
