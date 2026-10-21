// Where runs end: wave of death per mode/difficulty, for balance checks.
// dart run -DBOSSHP=0.8 tool/death_probe.dart 16
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 16;
  final only = const String.fromEnvironment('ONLY');
  for (final m in GameMode.values) {
    for (final d in Difficulty.values) {
      if (only.isNotEmpty && d.name != only) continue;
      var wins = 0;
      final deaths = <int>[];
      final reasons = <String>[];
      var winSecs = 0.0;
      for (var s = 0; s < runs; s++) {
        final r = simulateRun(
          GameConfig(mode: m, difficulty: d, seed: 1000 + s),
        );
        if (r.won) {
          wins++;
          winSecs += r.secs;
        } else {
          deaths.add(r.wave);
          reasons.add(
            '${r.wave}:${r.reason.contains('overrun') ? 'overrun' : 'timer'}',
          );
        }
      }
      deaths.sort();
      // ignore: avoid_print
      print(
        '${m.name} ${d.name}: win ${(100 * wins / runs).round()}% win mins ${wins == 0 ? '-' : (winSecs / wins / 60).toStringAsFixed(1)} deaths $reasons',
      );
    }
  }
}
