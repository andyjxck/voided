// Voided — painted sprites for the canvas. Loaded once at start-up; until
// they arrive (and in tests, where nothing loads) the painters fall back to
// the old drawn shapes.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/data.dart';

class Sprites {
  static final Map<String, ui.Image> _img = {};

  /// Ticks when a load finishes, so painters that cache can repaint.
  static final ValueNotifier<int> loaded = ValueNotifier(0);

  static ui.Image? unit(String id) => _seen('unit', id, _img['u_$id']);
  static ui.Image? enemy(String id) => _seen(
    'enemy',
    id,
    _img['e_$id'] ?? (id == 'wibble' ? _img['e_wobbler'] : null),
  );
  static ui.Image? boss(String id) => _seen('boss', id, _img['b_$id']);

  /// Build with --dart-define=SPRITECHECK=true to have the browser console
  /// report, every two seconds, which board characters were painted from a
  /// sprite and which fell back to a drawn shape. Off (and compiled out) in
  /// normal builds.
  static const bool _check = bool.fromEnvironment('SPRITECHECK');
  static final Map<String, Set<String>> _hit = {}, _miss = {};
  static ui.Image? _seen(String kind, String id, ui.Image? img) {
    if (_check) {
      (img == null ? _miss : _hit).putIfAbsent(kind, () => {}).add(id);
    }
    return img;
  }
  static ui.Image? named(String name) => _img[name];

  static Future<void> load() async {
    final names = <String>[
      for (final u in kUnits) 'u_${u.id}',
      for (final e in kEnemies) 'e_${e.id}',
      for (final id in kBossById.keys) 'b_$id',
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
    if (_check) {
      Timer.periodic(const Duration(seconds: 2), (_) {
        // ignore: avoid_print
        print('SPRITECHECK loaded=${_img.length} sprite=$_hit fallback=$_miss');
        _hit.clear();
        _miss.clear();
      });
    }
  }
}
