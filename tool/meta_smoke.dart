// ignore_for_file: avoid_print
import 'package:pier_pressure/game/balance.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/game/ai.dart';
import 'package:pier_pressure/game/sim.dart';

void main() {
  final m = MetaSave.decode(null);
  for (final mode in GameMode.values) {
    final g = Game(m.configFor(mode, Difficulty.calm, 7));
    final me = Bot(g, g.you, thinkEvery: 0.4);
    final mate = g.partner == null ? null : Bot(g, g.partner!, thinkEvery: 0.6, skill: 0.9);
    while (g.status == GameStatus.playing && g.time < 2400) {
      me.update(Game.step);
      mate?.update(Game.step);
      g.update(Game.step);
      g.fx.clear();
    }
    final s = m.finishRun(g);
    print('${mode.name}: ${g.status} wave ${g.wave} bosses ${g.bossesKilled} -> +${s.seaGlass} glass, best ${s.newBest}, '
        'jobs ${s.newMissions.map((x) => x.id).toList()}, ${s.unlocks}');
    final again = m.finishRun(g);
    print('  refinish same game: +${again.seaGlass}, runs ${m.runs}');
  }
  print('glass ${m.seaGlass}, maxDiff ${m.maxDifficulty}, album ${m.discovered.length}/${kUnits.length}');
  final bought = <String>[];
  for (final u in kMetaUpgrades) {
    if (m.buy(u)) bought.add(u.id);
  }
  print('bought $bought -> ${m.seaGlass} left; cfg bonusPennies ${m.configFor(GameMode.solo, Difficulty.calm, 1).bonusPennies}');
  final r = MetaSave.decode(m.encode());
  print('roundtrip equal: ${r.encode() == m.encode()}');
  print('corrupt -> fresh: ${MetaSave.decode('{not json').seaGlass == 0} ${MetaSave.decode('[1,2]').runs == 0}');
  final quick = simulateRun(const GameConfig(seed: 3), maxWave: 5);
  print('simulateRun ok: wave ${quick.wave}');
}
