// Win rate and wave of death on every level, for balance checks.
// dart run tool/all_levels_probe.dart 8 [calm|choppy|storm]
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 8;
  final d = args.length > 1
      ? Difficulty.values.firstWhere((x) => x.name == args[1])
      : Difficulty.calm;
  for (var level = 1; level <= kLevels.length; level++) {
    for (final m in GameMode.values) {
      var wins = 0;
      final waves = <int>[];
      for (var s = 0; s < runs; s++) {
        final r = simulateRun(
          GameConfig(mode: m, level: level, difficulty: d, seed: 700 + s),
        );
        if (r.won) wins++;
        waves.add(r.wave);
      }
      waves.sort();
      // ignore: avoid_print
      print('L$level ${m.name} ${d.name}: wins $wins/$runs waves $waves');
    }
  }
}
