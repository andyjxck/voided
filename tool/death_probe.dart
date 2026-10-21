// Where runs end: wave of death per mode/difficulty, for balance checks.
// dart run -DBOSSHP=0.8 tool/death_probe.dart 16
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 16;
  for (final m in GameMode.values) {
    for (final d in Difficulty.values) {
      var wins = 0;
      final deaths = <int>[];
      for (var s = 0; s < runs; s++) {
        final r = simulateRun(
          GameConfig(mode: m, difficulty: d, seed: 1000 + s),
        );
        if (r.won) {
          wins++;
        } else {
          deaths.add(r.wave);
        }
      }
      deaths.sort();
      // ignore: avoid_print
      print('${m.name} ${d.name}: win ${(100 * wins / runs).round()}% deaths $deaths');
    }
  }
}
