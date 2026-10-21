// Screen-reader support: the game screen's labels, the per-spot buttons, and
// the throttled spoken announcements.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/game/sim.dart';
import 'package:pier_pressure/ui/a11y.dart';
import 'package:pier_pressure/ui/game_screen.dart';

import 'helpers.dart';

/// Run [n] for [secs] seconds of real time at 60 frames a second.
List<Spoken> narrate(GameNarrator n, Game g, double secs, {bool sim = false}) {
  final out = <Spoken>[];
  for (var i = 0; i < (secs * 60).round(); i++) {
    if (sim) {
      g.update(1 / 60);
      g.fx.clear();
    }
    out.addAll(n.update(g, 1 / 60));
  }
  return out;
}

void addCrabs(Game g, int n) {
  final d = kEnemies.first;
  for (var i = 0; i < n; i++) {
    g.enemies.add(Enemy(9000 + g.enemies.length, d, null, 1e9, 0, 0, 0, 0));
  }
}

void main() {
  group('labels', () {
    test('HUD reads wave, time, lane, pennies and leaves in words', () {
      final g = Game(
        GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 1),
      );
      expect(hudLabel(g), startsWith('Get ready. Wave 1 in 4 seconds.'));
      advance(g, 6);
      final l = hudLabel(g);
      expect(l, contains('Wave 1 of 50. Next wave in '));
      expect(l, contains('of 100 sea things on the pier.'));
      expect(l, contains('${g.you.pennies} pennies, 0 tea leaves.'));
    });

    test(
      'HUD label only changes with whole seconds or counts, not every frame',
      () {
        final g = Game(
          GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 2),
        );
        var changes = 0;
        var last = hudLabel(g);
        for (var i = 0; i < 60 * 30; i++) {
          g.update(1 / 60);
          g.fx.clear();
          final l = hudLabel(g);
          if (l != last) changes++;
          last = l;
        }
        // 30 seconds: one change per second for the clock, plus spawns, kills
        // and pay. Every frame would be 1,800.
        expect(changes, lessThan(300));
      },
    );

    test('boss bar rounds health to 5% and names the boss', () {
      final g = gameAtBoss(10);
      expect(bossLabel(g), contains('Boss: ${g.boss!.name}'));
      expect(bossLabel(g), contains('100 percent health'));
      g.boss!.hp = g.boss!.maxHp * 0.612;
      expect(bossLabel(g), contains('65 percent health'));
    });

    test('board summary and spot labels', () {
      final g = Game(
        GameConfig(mode: GameMode.coop, difficulty: Difficulty.calm, seed: 4),
      );
      expect(
        boardSummary(g, g.you, owner: 'Your'),
        'Your board: empty, 18 spots free.',
      );
      final c = stack(g, g.you, kUnits.first.id, 3);
      final s = boardSummary(g, g.you, owner: 'Your');
      expect(s, contains('1 of 18 spots used. 3 ${kUnits.first.name}.'));
      expect(s, contains('1 spot ready to merge.'));
      expect(
        cellLabel(g, c),
        contains(
          '3 ${kUnits.first.name}, ${kUnits.first.tier.label}. Ready to merge.',
        ),
      );
      expect(
        cellLabel(g, c == 0 ? 1 : 0, selected: true),
        endsWith('empty. Selected.'),
      );
    });
  });

  group('narrator', () {
    test('announces wave 1 once, then stays quiet until wave 2', () {
      final g = Game(
        GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 5),
      );
      final said = narrate(
        GameNarrator(),
        g,
        10,
        sim: true,
      ).map((s) => s.text).toList();
      expect(said, ['Wave 1 of 50.']);
    });

    test('never more than one line per gap, and keeps only the newest few', () {
      final g = Game(
        GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 6),
      );
      final n = GameNarrator();
      for (var i = 0; i < 10; i++) {
        n.note('event $i');
      }
      final said = narrate(n, g, 10).map((s) => s.text).toList();
      expect(said, ['event 7', 'event 8', 'event 9']);
    });

    test('quick summons replace each other instead of queuing up', () {
      final g = Game(
        GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 10),
      );
      final n = GameNarrator();
      n.note('Summoned A, Common.', kind: 'summon');
      n.note('Summoned B, Common.', kind: 'summon');
      n.note('Not enough pennies.');
      n.note('Summoned C, Rare.', kind: 'summon');
      expect(narrate(n, g, 6).map((s) => s.text), [
        'Not enough pennies.',
        'Summoned C, Rare.',
      ]);
    });

    test(
      'a full minute of real play stays within one line per two seconds',
      () {
        final g = Game(
          GameConfig(mode: GameMode.coop, difficulty: Difficulty.calm, seed: 7),
        );
        final said = narrate(GameNarrator(), g, 60, sim: true);
        expect(said.length, lessThanOrEqualTo(31));
        expect(said.map((s) => s.text), contains('Wave 2 of 50.'));
      },
    );

    test('boss arrival, low timer and defeat', () {
      final g = gameAtBoss(10);
      final n = GameNarrator();
      final first = n.update(g, 1 / 60);
      expect(first.single.text, startsWith('Boss wave 10: ${g.boss!.name}'));
      expect(first.single.urgent, isTrue);
      g.bossTimer = 14.2;
      expect(narrate(n, g, 3).map((s) => s.text), [
        '15 seconds left on the boss.',
      ]);
      for (final b in g.bossList) {
        b.dead = true;
      }
      expect(narrate(n, g, 3).map((s) => s.text), ['Boss defeated.']);
    });

    test(
      'lane warnings rise once per band and re-arm only after the pier clears',
      () {
        final g = Game(
          GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 8),
        );
        final n = GameNarrator();
        narrate(n, g, 1);
        addCrabs(g, 52);
        expect(narrate(n, g, 3).map((s) => s.text), [
          'Warning: 52 of 100 sea things on the pier.',
        ]);
        // Hovering around the line says nothing more.
        g.enemies.removeRange(0, 4);
        addCrabs(g, 4);
        expect(narrate(n, g, 3), isEmpty);
        addCrabs(g, 40);
        final hi = narrate(n, g, 3);
        expect(hi.single.text, 'Warning: 92 of 100 sea things on the pier.');
        expect(hi.single.urgent, isTrue);
      },
    );

    test('the end of the run goes out at once, even mid-cooldown', () {
      final g = Game(
        GameConfig(mode: GameMode.solo, difficulty: Difficulty.calm, seed: 9),
      );
      final n = GameNarrator();
      n.note('something');
      n.update(g, 1 / 60);
      g.status = GameStatus.lost;
      g.endReason = 'The pier is overrun.';
      final said = n.update(g, 1 / 60);
      expect(
        said.single.text,
        'Game over. Reached wave 0. The pier is overrun.',
      );
      expect(n.update(g, 5), isEmpty);
    });
  });

  testWidgets('game screen: readable HUD, spot buttons, and spoken updates', (
    t,
  ) async {
    final sem = t.ensureSemantics();
    final spoken = <String>[];
    t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (msg) async {
        final m = msg as Map;
        if (m['type'] == 'announce') {
          spoken.add((m['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: GameScreen(
          meta: MetaSave()..tutorialDone = true,
          mode: GameMode.solo,
          difficulty: Difficulty.calm,
          onSave: () {},
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Get ready\. Wave 1 in \d seconds\. 0 of 100 sea things'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^The pier\. Your board: empty')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Spot 1, row 1: empty\.')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Spot 18, row 3: empty\.')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Summon a figurine, \d+ pennies$')),
      findsOneWidget,
    );

    await t.tap(find.textContaining('SUMMON').first);
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // The tree follows the game: the bar moved on, and the summon is on the board.
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Wave 1 of 50\. Next wave in \d+ seconds\.'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Spot \d+, row \d: 1 .+, \w+\.')),
      findsOneWidget,
    );
    expect(spoken.first, matches(RegExp(r'^Summoned .+, \w+\.$')));
    expect(spoken, contains('Wave 1 of 50.'));
    expect(spoken.length, lessThanOrEqualTo(6));
    await t.pumpWidget(const SizedBox());
    sem.dispose();
  });
}
