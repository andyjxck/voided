// Win rate and boss time left over many simulated runs, for tuning the
// twin bosses and the centre gate.
//   dart run tool/twin_probe.dart <coop|solo> <calm|choppy|storm> [runs]
// ignore_for_file: avoid_print
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> a) {
  final mode = GameMode.values.byName(a[0]);
  final diff = Difficulty.values.byName(a[1]);
  final runs = a.length > 2 ? int.parse(a[2]) : 16;
  var wins = 0;
  final left = <int, List<double>>{};
  var peak = 0;
  final losses = <String, int>{};
  for (var s = 0; s < runs; s++) {
    final r = simulateRun(
      GameConfig(mode: mode, difficulty: diff, seed: 1000 + s),
    );
    if (r.won) {
      wins++;
    } else {
      final k = r.reason.contains('timer')
          ? 'timer w${r.wave}'
          : 'overrun w${r.wave}';
      losses[k] = (losses[k] ?? 0) + 1;
    }
    r.bossTimeLeft.forEach((w, t) => (left[w] ??= []).add(t));
    if (r.peakLane > peak) peak = r.peakLane;
  }
  final bl = left.entries
      .map(
        (e) =>
            'w${e.key}:${(e.value.reduce((x, y) => x + y) / e.value.length).toStringAsFixed(0)}',
      )
      .join(' ');
  print(
    '${mode.name} ${diff.name}: win ${(100 * wins / runs).round()}% peak $peak losses $losses left $bl',
  );
}
