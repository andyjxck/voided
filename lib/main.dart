import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/sfx.dart';
import 'game/meta.dart';
import 'ui/menus.dart';
import 'ui/sprites.dart';

const kSaveKey = 'pier_pressure_save_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The board, boss bar and pickers paint figurines, riftlings and bosses
  // from these images; until they arrive the painters use drawn shapes.
  unawaited(Sprites.load());
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  final meta = MetaSave.decode(prefs?.getString(kSaveKey));
  Sfx.sound = meta.sound;
  Sfx.music = meta.music;
  runApp(
    PierPressureApp(
      meta: meta,
      save: () => prefs?.setString(kSaveKey, meta.encode()),
    ),
  );
}

class PierPressureApp extends StatelessWidget {
  final MetaSave meta;
  final VoidCallback save;
  const PierPressureApp({super.key, required this.meta, required this.save});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voided',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD34D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1630),
        useMaterial3: true,
      ),
      home: HomeScreen(meta: meta, save: save),
    );
  }
}
