// Prints every figurine, enemy and boss with its player-facing text as JSON.
// dart run tool/dump_text.dart
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:pier_pressure/game/data.dart';

void main() {
  print(
    const JsonEncoder.withIndent(' ').convert({
      'units': [
        for (final u in kUnits)
          {
            'id': u.id,
            'name': u.name,
            'tier': u.tier.name,
            'mono': u.mono,
            'tags': u.tags,
            'desc': u.desc,
            'quip': u.quip,
          },
      ],
      'enemies': [
        for (final e in kEnemies) {'id': e.id, 'name': e.name, 'blurb': e.blurb},
      ],
      'bosses': [
        for (final b in kBosses)
          {
            'id': b.id,
            'name': b.name,
            'title': b.title,
            'entrance': b.entrance,
            'defeat': b.defeat,
            'mech': b.mechText,
          },
      ],
    }),
  );
}
