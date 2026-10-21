// Drag-to-swap with a finger at phone size. Touch drags are only recognised
// after the touch slop, so the figurine must be picked up where the finger
// went down, not where the drag was recognised (step 3 browser playtest bug).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pressure/game/data.dart';
import 'package:pier_pressure/game/meta.dart';
import 'package:pier_pressure/ui/game_screen.dart';

void main() {
  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets('touch drag moves the figurine under the finger (${size.width.toInt()}x${size.height.toInt()})', (t) async {
      final sem = t.ensureSemantics();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: GameScreen(meta: MetaSave()..tutorialDone = true, mode: GameMode.solo, difficulty: Difficulty.calm, onSave: () {}),
      ));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.textContaining('SUMMON').first);
      await t.pump(const Duration(milliseconds: 100));

      final full = find.bySemanticsLabel(RegExp(r'^Spot \d+, row \d: 1 .+, \w+\.'));
      expect(full, findsOneWidget);
      final label = t.getSemantics(full).label;
      final from = int.parse(RegExp(r'^Spot (\d+)').firstMatch(label)!.group(1)!);
      final what = label.substring(label.indexOf(': ') + 2);
      // The far end of the same row, so the finger crosses the next spot
      // while the drag is still inside the touch slop.
      final rowStart = (from - 1) ~/ kBoardCols * kBoardCols;
      final col = (from - 1) % kBoardCols;
      final to = rowStart + (col < kBoardCols ~/ 2 ? kBoardCols : 1);
      final target = find.bySemanticsLabel(RegExp('^Spot $to, row \\d: empty'));
      expect(target, findsOneWidget);
      final a = t.getCenter(full), b = t.getCenter(target);
      expect(t.getSize(full).width, lessThan(60), reason: 'spots are near the touch slop in size on phones');

      await t.timedDragFrom(a, b - a, const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel(RegExp('^Spot $to, row \\d: ${RegExp.escape(what)}')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Spot $from, row \\d: empty')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      sem.dispose();
    });
  }
}
