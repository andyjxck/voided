// dart run tool/trace.dart coop|solo [seed]
// ignore_for_file: avoid_print
import 'package:pier_pressure/game/ai.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/sim.dart';

void main(List<String> args) {
  final mode = args.isNotEmpty && args[0] == 'solo'
      ? GameMode.solo
      : GameMode.coop;
  final seed = args.length > 1 ? int.parse(args[1]) : 1;
  final g = Game(GameConfig(mode: mode, seed: seed));
  final me = Bot(g, g.you, thinkEvery: 0.4);
  final mate = g.partner == null
      ? null
      : Bot(g, g.partner!, thinkEvery: 0.6, skill: 0.9);
  var w = 0;
  while (g.status == GameStatus.playing && g.time < 2400) {
    me.update(Game.step);
    mate?.update(Game.step);
    g.update(Game.step);
    g.fx.clear();
    if (g.wave != w) {
      w = g.wave;
      final p = g.you;
      final tiers = List.filled(5, 0);
      for (final u in p.allUnits) {
        tiers[u.def.tier.index]++;
      }
      print(
        'w$w t=${g.time.toStringAsFixed(0)} lane=${g.laneCount} dps=${g.sideDps(p).toStringAsFixed(0)}'
        '${g.partner != null ? '/${g.sideDps(g.partner!).toStringAsFixed(0)}' : ''} units=$tiers p=${p.pennies} '
        'leaves=${p.leaves} sum=${p.summons} upg=${p.upg} luck=${p.luck} hp=${g.enemyHp('drip', w).toStringAsFixed(0)} '
        'boss=${isBossWave(w) ? g.bossHp(w).toStringAsFixed(0) : '-'}',
      );
    }
  }
  print(
    '${g.status} wave ${g.wave} ${g.endReason} bossHpLeft=${g.boss == null ? '-' : (g.boss!.hp / g.boss!.maxHp).toStringAsFixed(2)}',
  );
}
