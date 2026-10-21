// Renders each screen with the real fonts and sprites to PNGs for a look by
// eye. Not part of the suite: flutter test test_shots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/ui/game_screen.dart';
import 'package:pier_pressure/ui/menus.dart';
import 'package:pier_pressure/ui/sprites.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

MetaSave vet() {
  final m = MetaSave()
    ..seaGlass = 412
    ..maxDifficulty = 1
    ..levelReached = 2
    ..tutorialDone = true
    ..runs = 7;
  m.discovered.addAll(kUnitById.keys.take(14));
  for (final id in kUnitById.keys.take(14)) {
    m.copies[id] = 9;
  }
  m.copies[kUnitById.keys.first] = 99;
  m.missions.addAll(['boss1', 'wave25', 'level1']);
  m.best['coop-L2'] = 31;
  m.upgrades['float'] = 2;
  return m;
}

void main() {
  setUpAll(() async {
    await _font('Lilita', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('Nunito', [
      'assets/fonts/Nunito-700.ttf',
      'assets/fonts/Nunito-800.ttf',
      'assets/fonts/Nunito-900.ttf',
    ]);
  });

  Future<void> shot(
    WidgetTester t,
    String name,
    Size size,
    Widget w, {
    Future<void> Function(WidgetTester)? then,
  }) async {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.runAsync(() async {
      await Sprites.load();
    });
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: w));
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pump(const Duration(milliseconds: 600));
    if (then != null) await then(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  const phone = Size(390, 844);
  const desk = Size(1280, 800);
  testWidgets(
    'home',
    (t) => shot(t, 'home', phone, HomeScreen(meta: vet(), save: () {})),
  );
  testWidgets(
    'home desk',
    (t) => shot(t, 'home_desk', desk, HomeScreen(meta: vet(), save: () {})),
  );
  testWidgets(
    'levels',
    (t) => shot(t, 'levels', phone, ModeSelect(meta: vet(), save: () {})),
  );
  testWidgets(
    'backroom',
    (t) => shot(t, 'backroom', phone, BackRoom(meta: vet(), save: () {})),
  );
  testWidgets('jobs', (t) => shot(t, 'jobs', phone, JobsBoard(meta: vet())));
  testWidgets('album', (t) => shot(t, 'album', phone, Album(meta: vet())));
  testWidgets('sea', (t) => shot(t, 'sea', phone, Bestiary(meta: vet())));
  testWidgets(
    'bosses',
    (t) => shot(
      t,
      'bosses',
      phone,
      Bestiary(meta: vet()),
      then: (t) async {
        await t.tap(find.text('BOSSES'));
        await t.pump(const Duration(milliseconds: 300));
      },
    ),
  );
  for (final (n, s) in [('game', phone), ('game_desk', desk)]) {
    testWidgets(
      n,
      (t) => shot(
        t,
        n,
        s,
        GameScreen(
          meta: vet(),
          mode: GameMode.coop,
          difficulty: Difficulty.calm,
          onSave: () {},
        ),
        then: (t) async {
          for (var i = 0; i < 6; i++) {
            await t.tap(find.text('SUMMON'));
            await t.pump(const Duration(milliseconds: 50));
          }
          await t.pump(const Duration(seconds: 8));
          final spot = find.bySemanticsLabel(RegExp(r'^Spot \d+, row \d+: \d'));
          expect(spot, findsWidgets);
          await t.tap(spot.first);
          await t.pump(const Duration(milliseconds: 300));
        },
      ),
    );
  }
}
