// Voided — painted sprites for the canvas. Loaded once at start-up; until
// they arrive (and in tests, where nothing loads) the painters fall back to
// the old drawn shapes.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';

class Sprites {
  static final Map<String, ui.Image> _img = {};

  /// Ticks when a load finishes, so painters that cache can repaint.
  static final ValueNotifier<int> loaded = ValueNotifier(0);

  static ui.Image? unit(String id) => _img['u_$id'];
  static ui.Image? enemy(String id) =>
      _img['e_${id == 'wibble' ? 'wobbler' : id}'];
  static ui.Image? boss(String id) => _img['b_$id'];
  static ui.Image? named(String name) => _img[name];

  static Future<void> load() async {
    final names = <String>[
      for (final u in kUnits) 'u_${u.id}',
      for (final e in kEnemies)
        if (e.id != 'wibble') 'e_${e.id}',
      for (final b in kBosses) 'b_${b.id}',
    ];
    await Future.wait(
      names.map((n) async {
        try {
          final data = await rootBundle.load('assets/sprites/$n.png');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          _img[n] = frame.image;
        } catch (_) {
          // Missing sprite: the drawn fallback stays.
        }
      }),
    );
    loaded.value++;
  }
}
