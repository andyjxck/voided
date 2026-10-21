// Screen-reader support for the game screen.
//
// The game redraws every frame, so nothing here may change on every frame:
// labels are built from whole seconds, whole cells and rounded percentages, so
// Flutter only sends a semantics update when something a listener cares about
// actually changed. Events go out as spoken announcements, throttled by
// [GameNarrator] so a busy wave never floods the screen reader.

import '../game/data.dart';
import '../game/sim.dart';

/// Spoken name for a board spot, counted from 1, row by row.
String spotName(int cell) => 'Spot ${cell + 1}, row ${cell ~/ kBoardCols + 1}';

/// What a screen reader reads for the top bar.
String hudLabel(Game g) {
  final p = g.you;
  final secs = (g.boss != null ? g.bossTimer : g.waveTimer).ceil();
  final String when;
  if (g.wave == 0) {
    when = 'Get ready. Wave 1 in $secs seconds.';
  } else if (g.boss != null) {
    when =
        'Wave ${g.wave}${g.endless ? '' : ' of $kFinalWave'}, boss wave. $secs seconds to beat the boss.';
  } else {
    when =
        'Wave ${g.wave}${g.endless ? ', Endless' : ' of $kFinalWave'}. Next wave in $secs seconds.';
  }
  return '$when ${g.laneCount} of $kLaneLimit sea things on the pier. '
      '${p.pennies} ${p.pennies == 1 ? 'penny' : 'pennies'}, ${p.leaves} tea ${p.leaves == 1 ? 'leaf' : 'leaves'}.';
}

/// What a screen reader reads for the boss bar. Health is rounded to 5% so the
/// label doesn't change on every hit.
String bossLabel(Game g) {
  final b = g.boss!;
  int pct(Enemy e) =>
      e.dead ? 0 : ((e.hp / e.maxHp).clamp(0.0, 1.0) * 20).ceil() * 5;
  final twins = g.bosses;
  if (twins.length < 2) {
    final shield = b.shield > 0 ? ' Shielded.' : '';
    return 'Boss: ${b.name}, ${b.boss!.title}. ${pct(b)} percent health.$shield ${g.bossTimer.ceil()} seconds left.';
  }
  String one(String side, Enemy e) => e.dead
      ? '$side one down'
      : '$side ${pct(e)} percent${e.shield > 0 ? ', shielded' : ''}';
  return 'Boss: ${b.name} times two, ${b.boss!.title}. '
      '${one('Left', twins[0])}, ${one('right', twins[1])}. '
      '${g.bossTimer.ceil()} seconds left.';
}

/// One spot on your board, for the invisible per-spot buttons.
String cellLabel(Game g, int i, {bool selected = false}) {
  final c = g.you.cells[i];
  final b = StringBuffer(spotName(i));
  if (c.isEmpty) {
    b.write(': empty.');
  } else {
    final d = c.def!;
    b.write(': ${c.units.length} ${d.name}, ${d.tier.label}.');
    if (g.canMerge(g.you, i)) b.write(' Ready to merge.');
  }
  if (c.disabled > 0) b.write(' Condemned for now.');
  if (selected) b.write(' Selected.');
  return b.toString();
}

/// A one-line summary of a whole board: how full it is and what is on it.
String boardSummary(Game g, PlayerSide p, {required String owner}) {
  final counts = <String, int>{};
  final tiers = <String, Tier>{};
  var used = 0;
  var mergeable = 0;
  for (var i = 0; i < p.cells.length; i++) {
    final c = p.cells[i];
    if (c.isEmpty) continue;
    used++;
    if (g.canMerge(p, i)) mergeable++;
    counts.update(
      c.def!.name,
      (v) => v + c.units.length,
      ifAbsent: () => c.units.length,
    );
    tiers[c.def!.name] = c.def!.tier;
  }
  if (used == 0) return '$owner board: empty, ${p.cells.length} spots free.';
  final names = counts.keys.toList()
    ..sort((a, b) => tiers[b]!.index.compareTo(tiers[a]!.index));
  final what = names.map((n) => '${counts[n]} $n').join(', ');
  final merge = mergeable > 0
      ? ' $mergeable ${mergeable == 1 ? 'spot' : 'spots'} ready to merge.'
      : '';
  return '$owner board: $used of ${p.cells.length} spots used. $what.$merge';
}

/// An announcement and whether it should interrupt.
class Spoken {
  final String text;
  final bool urgent;

  /// Lines of the same kind replace each other in the queue, so ten quick
  /// summons say the latest one, not ten lines twenty seconds late.
  final String? kind;
  const Spoken(this.text, {this.urgent = false, this.kind});
  @override
  String toString() => urgent ? '!$text' : text;
}

/// Turns game state changes into a few spoken lines.
///
/// Call [update] once per frame with the real (not game-speed) frame time and
/// [note] for one-off events the screen already shows (a new Epic, a gamble
/// result, an error toast). It speaks at most one line every [gap] seconds and
/// keeps at most [maxQueue] waiting, dropping the oldest, so the listener hears
/// what matters now, never a backlog. The end of the run always goes out at once.
class GameNarrator {
  GameNarrator({this.gap = 2.0, this.maxQueue = 3});
  final double gap;
  final int maxQueue;

  final List<Spoken> _queue = [];
  double _cool = 0;
  int _wave = 0;
  Object? _boss;
  bool _bossWarned = false;
  int _laneBand = 0;
  bool _started = false;
  GameStatus _status = GameStatus.playing;

  /// Lane fill points worth a warning, as fractions of [kLaneLimit].
  static const bands = [0.5, 0.75, 0.9];

  void note(String text, {bool urgent = false, String? kind}) {
    if (text.trim().isEmpty) return;
    _push(Spoken(text, urgent: urgent, kind: kind));
  }

  void _push(Spoken s) {
    _queue.removeWhere(
      (q) => q.text == s.text || (s.kind != null && q.kind == s.kind),
    );
    _queue.add(s);
    while (_queue.length > maxQueue) {
      _queue.removeAt(0);
    }
  }

  /// Lines to speak this frame (zero or one, plus the end of the run).
  List<Spoken> update(Game g, double dt) {
    _cool -= dt;
    final out = <Spoken>[];
    if (!_started) {
      _started = true;
      _wave = g.wave;
    }
    if (g.status != _status) {
      _status = g.status;
      _queue.clear();
      final head = g.status == GameStatus.won ? 'You won.' : 'Game over.';
      out.add(
        Spoken('$head Reached wave ${g.wave}. ${g.endReason}', urgent: true),
      );
      _cool = gap;
      return out;
    }
    if (g.status != GameStatus.playing) return out;

    final boss = g.boss;
    // The wave's first twin stands for the whole boss wave, so the second
    // taking the lead doesn't sound like a new boss arriving.
    final bossWave = boss == null
        ? null
        : (g.bosses.isNotEmpty ? g.bosses.first : boss);
    if (g.wave != _wave) {
      _wave = g.wave;
      if (boss == null) {
        _push(Spoken('Wave ${g.wave}${g.endless ? '' : ' of $kFinalWave'}.'));
      }
    }
    if (!identical(bossWave, _boss)) {
      if (boss != null) {
        _bossWarned = false;
        _push(
          Spoken(
            'Boss wave ${g.wave}: ${g.bosses.length > 1 ? '${boss.name} times two, one each way' : boss.name}, ${boss.boss!.title}. ${boss.boss!.mechText} '
            '${g.bossTimer.ceil()} seconds to beat it.',
            urgent: true,
          ),
        );
      } else if (_boss != null) {
        _push(const Spoken('Boss defeated.'));
      }
      _boss = bossWave;
    }
    if (boss != null && !_bossWarned && g.bossTimer <= 15) {
      _bossWarned = true;
      _push(
        Spoken('${g.bossTimer.ceil()} seconds left on the boss.', urgent: true),
      );
    }

    // Lane warnings rise a band at a time and only re-arm once the pier has
    // cleared well below the band, so a count hovering at a line stays quiet.
    final f = g.laneCount / kLaneLimit;
    var band = _laneBand;
    while (band < bands.length && f >= bands[band]) {
      band++;
    }
    while (band > 0 && f < bands[band - 1] - 0.15) {
      band--;
    }
    if (band > _laneBand) {
      _push(
        Spoken(
          'Warning: ${g.laneCount} of $kLaneLimit sea things on the pier.',
          urgent: band == bands.length,
        ),
      );
    }
    _laneBand = band;

    if (_queue.isNotEmpty && _cool <= 0) {
      // Anything urgent jumps the queue.
      final i = _queue.indexWhere((q) => q.urgent);
      out.add(_queue.removeAt(i < 0 ? 0 : i));
      _cool = gap;
    }
    return out;
  }
}
