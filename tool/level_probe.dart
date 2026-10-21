// Quick level balance probe: bot runs per level and mode.
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 8;
  final skill = args.length > 1 ? double.parse(args[1]) : 1.0;
  for (final level in [1, 2]) {
    for (final m in GameMode.values) {
      var wins = 0;
      final waves = <int>[];
      final peaks = <int>[];
      for (var s = 0; s < runs; s++) {
        final r = simulateRun(
          GameConfig(mode: m, level: level, seed: 500 + s),
          playerSkill: skill,
          playerThink: skill < 1 ? 0.8 : 0.4,
        );
        if (r.won) wins++;
        waves.add(r.wave);
        peaks.add(r.peakLane);
      }
      waves.sort();
      // ignore: avoid_print
      print(
        'level $level ${m.name} skill $skill: wins $wins/$runs waves $waves peak $peaks',
      );
    }
  }
}
