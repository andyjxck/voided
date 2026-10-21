import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

/// Run the game loop for [secs] seconds of game time.
void advance(Game g, double secs) {
  final steps = (secs / Game.step).round();
  for (var i = 0; i < steps; i++) {
    g.update(Game.step);
    g.fx.clear();
  }
}

/// Start the boss wave [wave] (10, 20, 30, 40) straight away.
Game gameAtBoss(
  int wave, {
  GameMode mode = GameMode.coop,
  Difficulty difficulty = Difficulty.calm,
}) {
  final g = Game(GameConfig(mode: mode, difficulty: difficulty, seed: 3));
  g.wave = wave - 1;
  g.startNextWave();
  return g;
}

/// Fill one cell of [p] with [n] copies of figurine [id]. Returns the cell.
int stack(Game g, PlayerSide p, String id, int n) {
  var cell = -1;
  for (var i = 0; i < n; i++) {
    cell = g.place(p, kUnitById[id]!);
  }
  return cell;
}

/// Put a Lifeguard Lou (long range) in every cell of [p].
void fillBoard(PlayerSide p) {
  for (var i = 0; i < p.cells.length; i++) {
    p.cells[i].units
      ..clear()
      ..add(UnitInst(kUnitById['lou']!, 5000 + i, 0));
  }
}
