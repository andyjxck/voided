import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/sim.dart';
import 'widgets.dart';

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

/// The one-line strip under the HUD: what is switched on right now. Tap it
/// for the full list.
class SynergyStrip extends StatelessWidget {
  final Game g;
  final VoidCallback onTap;
  const SynergyStrip({super.key, required this.g, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = g.you;
    g.refreshBonds(p);
    final members = unionMembers(p);
    final items = <(String, Color)>[];
    final tags = members.keys.toList()..sort();
    for (final t in tags) {
      final n = members[t]!.length;
      if (n < 2) continue;
      final on = n >= 3 && !p.redacted.containsKey(t);
      items.add(('$t $n/${n >= 3 ? 5 : 3}', on ? Vx.text : Vx.textDim));
    }
    final seen = <String>{};
    for (final b in p.bonds) {
      if (seen.add(b.def.name)) {
        items.add((b.k > 1 ? '${b.def.name} x2' : b.def.name, kBondGold));
      }
    }
    final hoard = g.hoardBonus(p);
    final interest = interestFor(p.pennies);
    final cut = g.bondsCut > 0;
    final label = [
      if (items.isEmpty) 'No unions or bonds yet',
      for (final i in items) i.$1,
      if (cut) 'Bonds cut',
      if (hoard > 0) 'Hoard plus ${(hoard * 100).round()}% damage',
      if (interest > 0) 'Interest $interest a wave',
    ].join(', ');
    return Semantics(
      button: true,
      label: 'Synergies: $label. Tap for unions, bonds and house rules.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: const Color(0x99120E0A),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (items.isEmpty)
                        Text(
                          'No unions or bonds yet',
                          style: body(11.5, color: Vx.textDim),
                        ),
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          Text('  ·  ', style: body(11.5, color: Vx.textDim)),
                        Text(
                          items[i].$1,
                          style: body(11.5, color: items[i].$2),
                        ),
                      ],
                      if (cut)
                        Text(
                          '  ·  Bonds cut',
                          style: body(11.5, color: const Color(0xFFDC8A70)),
                        ),
                    ],
                  ),
                ),
              ),
              if (hoard > 0 || interest > 0)
                Text(
                  [
                    if (hoard > 0) '+${(hoard * 100).round()}% dmg',
                    if (interest > 0) '+$interest/wave',
                  ].join('  '),
                  style: body(11.5, color: kBondGold),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.info_outline, size: 14, color: Vx.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Synergies sheet: unions, bonds and house rules, as plain lines.
class SynergySheet extends StatelessWidget {
  final Game g;
  const SynergySheet({super.key, required this.g});

  Widget _heading(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
    child: Text(t, style: display(15, color: kBondGold, w: 1.4)),
  );

  @override
  Widget build(BuildContext context) {
    final p = g.you;
    g.refreshBonds(p);
    final members = unionMembers(p);
    final owned = {for (final u in p.allUnits) u.def.id};
    final onBonds = {
      for (final b in [...p.bonds, ...p.bondsWaiting]) b.def,
    };
    final unions = kUnionRules.keys.toList();
    final hoard = g.hoardBonus(p);
    final bonds = [...kBonds]
      ..sort((a, b) {
        int rank(BondDef d) => onBonds.contains(d)
            ? 0
            : (owned.contains(d.a) && owned.contains(d.b))
            ? 1
            : (owned.contains(d.a) || owned.contains(d.b))
            ? 2
            : 3;
        return rank(a).compareTo(rank(b));
      });
    String nameOf(String id) => kUnitById[id]?.name ?? id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Unions'),
        Text(
          'Three different figurines of one union switch on its bonus. Five add a second.',
          style: body(12, color: Vx.textDim),
        ),
        const SizedBox(height: 4),
        for (final t in unions) ...[
          () {
            final n = members[t]?.length ?? 0;
            final on3 = n >= 3 && !p.redacted.containsKey(t);
            final on5 = n >= 5 && !p.redacted.containsKey(t);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$t $n/3  ',
                      style: body(12.5, color: on3 ? kBondGold : Vx.text),
                    ),
                    TextSpan(
                      text: kUnionRules[t] ?? '',
                      style: body(12, color: on3 ? Vx.text : Vx.textDim),
                    ),
                    if (kUnion5Rules[t] != null)
                      TextSpan(
                        text: '  At 5: ${kUnion5Rules[t]}',
                        style: body(12, color: on5 ? Vx.text : Vx.textDim),
                      ),
                  ],
                ),
              ),
            );
          }(),
        ],
        _heading('Bonds'),
        Text(
          g.bondsCut > 0
              ? 'The Severer has cut every bond for ${g.bondsCut.ceil()}s.'
              : 'Put these pairs in touching cells, diagonals too. Both get the bonus.',
          style: body(12, color: Vx.textDim),
        ),
        const SizedBox(height: 4),
        for (final b in bonds)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${b.name}  ',
                    style: body(
                      12.5,
                      color: onBonds.contains(b) ? kBondGold : Vx.text,
                    ),
                  ),
                  TextSpan(
                    text: '${nameOf(b.a)} + ${nameOf(b.b)}: ${b.effect}.',
                    style: body(
                      12,
                      color: onBonds.contains(b) ? Vx.text : Vx.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _heading('House rules'),
        for (final r in kHouseRules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${r.name}  ', style: body(12.5)),
                  TextSpan(
                    text: r.line,
                    style: body(12, color: Vx.textDim),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          [
            'You hold ${p.pennies} pennies',
            g.hoardBlocked
                ? 'Hoard is blocked right now'
                : 'Hoard +${(hoard * 100).round()}%',
            'interest ${interestFor(p.pennies)} a wave',
          ].join(' · '),
          style: body(12, color: kBondGold),
        ),
      ],
    );
  }
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
