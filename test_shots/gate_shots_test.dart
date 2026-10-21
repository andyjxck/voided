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
  for (final mode in GameMode.values) {
    for (final (dev, size) in [('phone', phone), ('desk', desk)]) {
      for (final boss in [false, true]) {
        final name = 'gate-${mode.name}-$dev-${boss ? 'boss' : 'pairs'}';
        testWidgets(name, (t) async {
          await shot(
            t,
            name,
            size,
            GameScreen(
              meta: vet(),
              mode: mode,
              difficulty: Difficulty.calm,
              onSave: () {},
            ),
            then: (t) async {
              final st = t.state(find.byType(GameScreen)) as dynamic;
              final g = st.g;
              g.enemies.clear();
              g.wave = boss ? 9 : 2;
              g.startNextWave();
              await t.pump(const Duration(milliseconds: 100));
              for (var i = 0; i < 40; i++) {
                await t.pump(const Duration(milliseconds: 100));
              }
            },
          );
        });
      }
    }
  }
}
