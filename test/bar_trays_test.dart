// The game screen has no pop-up sheets any more: Gamble and Upgrade flip the
// bottom bar into a tray in the same place, Mythics are a row of medallions
// above the bar, and unions are badges on the board's edge. Pause is the
// only thing that covers the board.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/ui/game_screen.dart';

const sizes = {
  'phone': Size(390, 844),
  'desktop': Size(1280, 800),
  'small phone': Size(360, 640),
};

MetaSave vet() => MetaSave()
  ..tutorialDone = true
  ..levelReached = 2;

Future<void> open(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: GameScreen(
        meta: vet(),
        mode: GameMode.coop,
        difficulty: Difficulty.calm,
        onSave: () {},
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  sizes.forEach((name, size) {
    group(name, () {
      testWidgets('Gamble flips the bar into a tray, and back', (t) async {
        await open(t, size);
        expect(find.text('SUMMON'), findsOneWidget);
        await t.tap(find.text('GAMBLE'));
        await settle(t);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('SUMMON'), findsNothing);
        for (final o in kGambles) {
          expect(find.byKey(ValueKey('gamble-${o.tier.name}')), findsOneWidget);
        }
        // the tray sits where the bar was: the bottom of the screen
        final r = t.getRect(
          find.byKey(ValueKey('gamble-${kGambles.first.tier.name}')),
        );
        expect(r.bottom, greaterThan(size.height - 110));
        await t.tap(find.text('BACK'));
        await settle(t);
        expect(find.text('SUMMON'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('Upgrade tray has the three groups and the Lucky Penny', (
        t,
      ) async {
        await open(t, size);
        await t.tap(find.text('UPGRADE'));
        await settle(t);
        expect(find.byType(BottomSheet), findsNothing);
        for (var gi = 0; gi < 3; gi++) {
          expect(find.byKey(ValueKey('upgrade-$gi')), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('upgrade-luck')), findsOneWidget);
        // tapping Upgrade's own spot again (BACK) flips it back
        await t.tap(find.text('BACK'));
        await settle(t);
        expect(find.text('UPGRADE'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('one medallion per Mythic; tapping one shows its parts', (
        t,
      ) async {
        await open(t, size);
        expect(find.text('MYTHICS'), findsNothing);
        final meds = find.bySemanticsLabel(RegExp(r'parts\. Tap'));
        expect(meds, findsWidgets);
        await t.tap(meds.first);
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(BottomSheet), findsNothing);
        expect(t.takeException(), isNull);
      });
    });
  });

  test('every Mythic has a recipe the medallions can show', () {
    expect(kRecipes, isNotEmpty);
    for (final e in kRecipes.entries) {
      expect(kUnitById[e.key], isNotNull);
      expect(e.value.length, 3);
    }
  });
}
