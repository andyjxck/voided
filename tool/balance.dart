// dart run tool/balance.dart [runs] [soloMult]
// ignore_for_file: avoid_print
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 20;
  final soloMult = args.length > 1 ? double.parse(args[1]) : kSoloHpMultiplier;
  final skill = args.length > 2 ? double.parse(args[2]) : 1.0;
  for (final diff in Difficulty.values) {
    for (final mode in GameMode.values) {
      var wins = 0;
      final waves = <int>[];
      final reasons = <String, int>{};
      final bossLeft = <int, List<double>>{};
      var peak = 0;
      for (var s = 0; s < runs; s++) {
        final cfg = GameConfig(
            mode: mode, difficulty: diff, seed: 1000 + s, hpScaleOverride: mode == GameMode.solo ? soloMult : 1.0);
        final r = simulateRun(cfg, playerSkill: skill);
        if (r.won) wins++;
        waves.add(r.wave);
        if (!r.won) {
          final k = r.reason.contains('timer') ? 'boss timer w${r.wave}' : 'overrun';
          reasons[k] = (reasons[k] ?? 0) + 1;
        }
        r.bossTimeLeft.forEach((w, t) => (bossLeft[w] ??= []).add(t));
        if (r.peakLane > peak) peak = r.peakLane;
      }
      waves.sort();
      final bl = bossLeft.entries.map((e) => 'w${e.key}:${(e.value.reduce((a, b) => a + b) / e.value.length).toStringAsFixed(0)}s(${e.value.length})').join(' ');
      print('${diff.name.padRight(7)} ${mode.name.padRight(5)} win ${(100 * wins / runs).toStringAsFixed(0).padLeft(3)}%  '
          'median wave ${waves[runs ~/ 2]}  min ${waves.first}  peakLane $peak  losses $reasons  bossLeft $bl');
    }
  }
}
