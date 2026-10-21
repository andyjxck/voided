// Balance probe: bot win rates per level, mode and difficulty.
// dart run tool/diff_probe.dart [runs] [levels]
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 16;
  final levels = args.length > 1 ? int.parse(args[1]) : 1;
  for (var level = 1; level <= levels; level++) {
    for (final m in GameMode.values) {
      for (final d in Difficulty.values) {
        for (final slow in [false, true]) {
          if (slow && d != Difficulty.calm) continue;
          var wins = 0;
          final waves = <int>[];
          final left = <double>[];
          for (var s = 0; s < runs; s++) {
            final r = simulateRun(
              GameConfig(mode: m, difficulty: d, level: level, seed: 1000 + s),
              playerSkill: slow ? 0.5 : 1,
              playerThink: slow ? 1.5 : 0.4,
            );
            if (r.won) wins++;
            waves.add(r.wave);
            if (r.bossTimeLeft[kFinalWave] case final t?) left.add(t);
          }
          waves.sort();
          final l = left.isEmpty ? 0 : left.reduce((a, b) => a + b) / left.length;
          // ignore: avoid_print
          print('L$level ${m.name} ${d.name}${slow ? ' slow' : ''}: win ${(100 * wins / runs).round()}% median ${waves[runs ~/ 2]} left ${l.toStringAsFixed(0)}s');
        }
      }
    }
  }
}
