// Headless full-run simulation used by tests and tool/balance.dart.

import 'ai.dart';
import 'data.dart';
import 'sim.dart';

class RunResult {
  final bool won;
  final int wave;
  final String reason;
  final int peakLane;
  final double secs;
  final Map<int, double> bossTimeLeft;
  RunResult(this.won, this.wave, this.reason, this.peakLane, this.secs, this.bossTimeLeft);
}

RunResult simulateRun(GameConfig cfg, {double playerSkill = 1.0, double playerThink = 0.4, int maxWave = kFinalWave}) {
  final g = Game(cfg);
  final me = Bot(g, g.you, thinkEvery: playerThink, skill: playerSkill);
  final mate = g.partner == null ? null : Bot(g, g.partner!, thinkEvery: 0.6, skill: 0.9);
  const dt = Game.step;
  final bossLeft = <int, double>{};
  while (g.status == GameStatus.playing && g.time < 60 * 40) {
    me.update(dt);
    mate?.update(dt);
    final hadBoss = g.boss != null;
    final left = g.bossTimer;
    final w = g.wave;
    g.update(dt);
    if (hadBoss && g.boss == null) bossLeft[w] = left;
    g.fx.clear();
    if (g.wave > maxWave) break;
  }
  return RunResult(g.status == GameStatus.won, g.wave, g.endReason, g.peakLane, g.time, bossLeft);
}
