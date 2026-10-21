// Every screen at phone (390 x 844) and desktop (1280 x 800): no overflow,
// no exceptions, and the game screen survives a stretch of real play.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/main.dart';
import 'package:pier_pressure/ui/game_screen.dart';
import 'package:pier_pressure/ui/menus.dart';

const sizes = {
  'phone': Size(390, 844),
  'desktop': Size(1280, 800),
  'small phone': Size(360, 640),
};

Future<void> show(WidgetTester t, Size size, Widget w) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: w,
    ),
  );
  await t.pump(const Duration(milliseconds: 500));
}

MetaSave veteran() {
  final m = MetaSave()
    ..seaGlass = 999
    ..maxDifficulty = 2
    ..tutorialDone = true;
  m.discovered.addAll(kUnitById.keys.take(10));
  m.missions.addAll(['win', 'first_boss']);
  m.best['coop-calm'] = 40;
  return m;
}

void main() {
  sizes.forEach((name, size) {
    group(name, () {
      testWidgets('home, new player', (t) async {
        await show(t, size, PierPressureApp(meta: MetaSave(), save: () {}));
        expect(find.text('PLAY'), findsOneWidget);
      });
      testWidgets('mode select', (t) async {
        await show(t, size, ModeSelect(meta: veteran(), save: () {}));
        await t.scrollUntilVisible(
          find.text('OPEN UP'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('OPEN UP'), findsOneWidget);
      });
      testWidgets('back room', (t) async {
        await show(t, size, BackRoom(meta: veteran(), save: () {}));
      });
      testWidgets('jobs board', (t) async {
        await show(t, size, JobsBoard(meta: veteran()));
      });
      testWidgets('album', (t) async {
        await show(t, size, Album(meta: veteran()));
      });
      testWidgets('bestiary', (t) async {
        await show(t, size, Bestiary(meta: veteran()));
      });
      for (final mode in GameMode.values) {
        testWidgets('game, ${mode.name}, 40 seconds in', (t) async {
          await show(
            t,
            size,
            GameScreen(
              meta: veteran(),
              mode: mode,
              difficulty: Difficulty.calm,
              onSave: () {},
            ),
          );
          for (var i = 0; i < 400; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          final summon = find.textContaining('SUMMON');
          expect(summon, findsWidgets);
          await t.tap(summon.first, warnIfMissed: false);
          await t.pump(const Duration(milliseconds: 300));
          await t.pumpWidget(const SizedBox());
        });
      }
      testWidgets('game with the tutorial', (t) async {
        await show(
          t,
          size,
          GameScreen(
            meta: MetaSave(),
            mode: GameMode.coop,
            difficulty: Difficulty.calm,
            onSave: () {},
            tutorial: true,
          ),
        );
        expect(find.textContaining('Welcome to Grimley Pier'), findsOneWidget);
        await t.tap(find.text('Next'));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Feed the machine'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      });
    });
  });
}
