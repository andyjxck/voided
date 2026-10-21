// Sound: everything is synthesised live with Web Audio, so the game ships
// with no audio files and spends nobody's voice credits. Off the web
// (tests) it is silent.

import 'sfx_stub.dart' if (dart.library.js_interop) 'sfx_web.dart' as impl;

class Sfx {
  static bool sound = true;
  static bool music = true;
  static double _lastHit = 0;
  static double _lastKill = 0;

  static void unlock() => impl.unlock();

  static void _p(String name, [double v = 0]) {
    if (!sound) return;
    impl.play(name, v);
  }

  static void click() => _p('click');
  static void summon(int tier) => _p('summon', tier.toDouble());
  static void merge(int tier) => _p('merge', tier.toDouble());
  static void mythic() => _p('mythic');
  static void sell() => _p('sell');
  static void error() => _p('error');
  static void boss() => _p('boss');
  static void win() => _p('win');
  static void lose() => _p('lose');
  static void gamble(bool won) => _p(won ? 'gambleWin' : 'gambleLose');
  static void freeze() => _p('freeze');
  static void jackpot() => _p('jackpot');
  static void condemn() => _p('condemn');
  static void upgrade() => _p('upgrade');

  static void hit(double now) {
    if (now - _lastHit < 0.07) return;
    _lastHit = now;
    _p('hit');
  }

  static void kill(double now, bool big) {
    if (!big && now - _lastKill < 0.05) return;
    _lastKill = now;
    _p(big ? 'bigKill' : 'kill');
  }

  static void setMusic(bool on, {bool tense = false}) {
    music = on;
    impl.music(on, tense);
  }

  static void musicMood(bool tense) {
    if (music) impl.music(true, tense);
  }
}
