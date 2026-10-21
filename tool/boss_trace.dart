// Trace a boss wave: each boss's health and position every 5s.
// dart run tool/boss_trace.dart solo calm 1003 30
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
  final target = int.parse(a[3]);
  final me = Bot(g, g.you, thinkEvery: 0.4, skill: 1.0);
  final mate = g.partner == null
      ? null
      : Bot(g, g.partner!, thinkEvery: 0.6, skill: 0.9);
  var next = 0.0;
  while (g.status == GameStatus.playing && g.wave <= target) {
    me.update(Game.step);
    mate?.update(Game.step);
    g.update(Game.step);
    g.fx.clear();
    if (g.wave == target && g.time >= next) {
      next = g.time + 5;
      final bs = g.bossList
          .map((b) {
            final p = g.field.at(b);
            return '${b.boss!.id}/r${b.route} ${(100 * b.hp / b.maxHp).round()}% '
                '(${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)})${b.dead ? ' dead' : ''}';
          })
          .join(' | ');
      // ignore: avoid_print
      print(
        't=${g.bossTimer.toStringAsFixed(0)} units=${g.you.cells.where((c) => c.units.isNotEmpty).length} sea=${g.enemies.length} $bs',
      );
    }
  }
  // ignore: avoid_print
  print('end: ${g.status.name} wave ${g.wave} ${g.endReason}');
}
