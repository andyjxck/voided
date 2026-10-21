// Board strength at the start of each 5th wave: cells used, figurines, leftover sea things.
// dart run tool/board_trace.dart solo calm 1001
import 'package:pier_pressure/game/ai.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> a) {
  final g = Game(
    GameConfig(
      mode: GameMode.values.byName(a[0]),
      difficulty: Difficulty.values.byName(a[1]),
      seed: int.parse(a[2]),
    ),
  );
  final me = Bot(g, g.you, thinkEvery: 0.4, skill: 1.0);
  final mate = g.partner == null
      ? null
      : Bot(g, g.partner!, thinkEvery: 0.6, skill: 0.9);
  var last = 0;
  final out = <String>[];
  while (g.status == GameStatus.playing && g.wave <= 50) {
    me.update(Game.step);
    mate?.update(Game.step);
    g.update(Game.step);
    g.fx.clear();
    if (g.wave != last) {
      last = g.wave;
      if (g.wave % 5 == 0 || g.wave % 10 == 9) {
        final figs = g.you.cells.fold<int>(0, (s, c) => s + c.units.length);
        out.add(
          'w${g.wave}: cells ${g.you.cells.where((c) => c.units.isNotEmpty).length} figs $figs sea ${g.enemies.length}',
        );
      }
    }
  }
  // ignore: avoid_print
  print('${out.join(' | ')} | end ${g.status.name} w${g.wave}');
}
