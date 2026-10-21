// Prints every figurine, sea thing and boss id as JSON, straight from data.dart.
// dart run tool/dump_ids.dart
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:pier_pressure/game/data.dart';

void main() {
  print(
    jsonEncode({
      'units': [for (final u in kUnits) u.id],
      'enemies': [for (final e in kEnemies) e.id],
      'bosses': [for (final b in kBosses) b.id],
    }),
  );
}
