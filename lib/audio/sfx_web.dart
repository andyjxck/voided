// Web Audio synth: blips, chords, a fog-horn and a wonky end-of-the-pier
// waltz on a fairground organ.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external factory _Ctx();
  external double get currentTime;
  external double get sampleRate;
  external String get state;
  external _Node get destination;
  external _Osc createOscillator();
  external _Gain createGain();
  external _Filter createBiquadFilter();
  external _Buffer createBuffer(int channels, int length, double rate);
  external _BufSrc createBufferSource();
  external JSPromise<JSAny?> resume();
}

extension type _Node._(JSObject _) implements JSObject {
  external _Node connect(_Node other);
}

extension type _Param._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double v, double t);
  external void linearRampToValueAtTime(double v, double t);
  external void exponentialRampToValueAtTime(double v, double t);
}

extension type _Osc._(JSObject _) implements _Node {
  external set type(String t);
  external _Param get frequency;
  external void start(double t);
  external void stop(double t);
}

extension type _Gain._(JSObject _) implements _Node {
  external _Param get gain;
}

extension type _Filter._(JSObject _) implements _Node {
  external set type(String t);
  external _Param get frequency;
}

extension type _Buffer._(JSObject _) implements JSObject {
  external JSFloat32Array getChannelData(int c);
}

extension type _BufSrc._(JSObject _) implements _Node {
  external set buffer(_Buffer b);
  external void start(double t);
  external void stop(double t);
}

_Ctx? _ctx;
_Gain? _master;
_Gain? _musicBus;
_Buffer? _noise;
bool _failed = false;

_Ctx? _c() {
  if (_ctx != null || _failed) return _ctx;
  try {
    final c = _Ctx();
    _ctx = c;
    _master = c.createGain()..gain.value = 0.55;
    _master!.connect(c.destination);
    _musicBus = c.createGain()..gain.value = 0.0001;
    _musicBus!.connect(_master!);
    final len = (c.sampleRate * 0.5).round();
    final b = c.createBuffer(1, len, c.sampleRate);
    final data = b.getChannelData(0).toDart;
    final r = math.Random(7);
    for (var i = 0; i < len; i++) {
      data[i] = r.nextDouble() * 2 - 1;
    }
    _noise = b;
  } catch (_) {
    _failed = true;
    _ctx = null;
  }
  return _ctx;
}

void unlock() {
  final c = _c();
  if (c != null && c.state != 'running') {
    try {
      c.resume();
    } catch (_) {}
  }
}

void _tone(double f, double dur,
    {String type = 'square', double vol = 0.2, double at = 0, double? slide, _Node? out, double attack = 0.005}) {
  final c = _c();
  if (c == null) return;
  final t = c.currentTime + math.max(0, at);
  final o = c.createOscillator()..type = type;
  o.frequency.setValueAtTime(f, t);
  if (slide != null) o.frequency.exponentialRampToValueAtTime(math.max(20, slide), t + dur);
  final g = c.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(vol, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g);
  g.connect(out ?? _master!);
  o.start(t);
  o.stop(t + dur + 0.05);
}

void _noiseBurst(double dur, {double vol = 0.2, double freq = 1200, double at = 0, String type = 'lowpass'}) {
  final c = _c();
  if (c == null || _noise == null) return;
  final t = c.currentTime + math.max(0, at);
  final s = c.createBufferSource()..buffer = _noise!;
  final f = c.createBiquadFilter()..type = type;
  f.frequency.setValueAtTime(freq, t);
  final g = c.createGain();
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  s.connect(f);
  f.connect(g);
  g.connect(_master!);
  s.start(t);
  s.stop(t + dur + 0.05);
}

double _n(int semis) => 440.0 * math.pow(2, semis / 12);

final _r = math.Random();

void play(String name, double v) {
  if (_c() == null) return;
  try {
    _play(name, v);
  } catch (_) {}
}

void _play(String name, double v) {
  switch (name) {
    case 'click':
      _tone(900, 0.04, type: 'triangle', vol: 0.12);
    case 'summon':
      const notes = [0, 4, 7, 12, 16];
      final n = 2 + v.round();
      for (var i = 0; i < n; i++) {
        _tone(_n(notes[i % 5] + 3), 0.12 + v * 0.03, at: i * 0.05, vol: 0.12 + v * 0.03, type: v >= 3 ? 'sawtooth' : 'square');
      }
      if (v >= 3) _noiseBurst(0.4, vol: 0.15, freq: 4000, type: 'highpass', at: 0.15);
    case 'merge':
      for (final s in [0, 4, 7, 12]) {
        _tone(_n(s + 5 + v.round() * 2), 0.35, type: 'triangle', vol: 0.12);
      }
      _tone(_n(17 + v.round() * 2), 0.25, at: 0.12, vol: 0.12);
    case 'mythic':
      const seq = [0, 4, 7, 12, 7, 12, 16, 19];
      for (var i = 0; i < seq.length; i++) {
        _tone(_n(seq[i]), 0.2, at: i * 0.07, type: 'sawtooth', vol: 0.12);
      }
      _tone(_n(-12), 1.0, type: 'triangle', vol: 0.25, at: 0.5);
      _noiseBurst(0.8, vol: 0.12, freq: 6000, type: 'highpass', at: 0.5);
    case 'sell':
      _tone(1400, 0.06, vol: 0.1);
      _tone(1900, 0.1, at: 0.05, vol: 0.1);
    case 'error':
      _tone(160, 0.15, type: 'sawtooth', vol: 0.1);
    case 'hit':
      _noiseBurst(0.04, vol: 0.05, freq: 2500);
    case 'kill':
      _tone(600 + _r.nextDouble() * 300, 0.07, slide: 200, type: 'square', vol: 0.05);
    case 'bigKill':
      _noiseBurst(0.9, vol: 0.35, freq: 600);
      _tone(110, 0.8, slide: 40, type: 'sawtooth', vol: 0.25);
    case 'boss':
      _tone(73, 1.6, type: 'sawtooth', vol: 0.22, attack: 0.15);
      _tone(73.6, 1.6, type: 'sawtooth', vol: 0.18, attack: 0.15);
      _tone(55, 1.2, type: 'square', vol: 0.12, at: 1.4, attack: 0.1);
    case 'win':
      const seq = [0, 4, 7, 12, 16, 19, 24];
      for (var i = 0; i < seq.length; i++) {
        _tone(_n(seq[i] - 5), 0.4, at: i * 0.11, type: 'triangle', vol: 0.18);
      }
    case 'lose':
      for (var i = 0; i < 4; i++) {
        _tone(_n(-5 - i * 2), 0.45, at: i * 0.3, type: 'triangle', vol: 0.18, slide: _n(-6 - i * 2));
      }
    case 'gambleWin':
      for (var i = 0; i < 6; i++) {
        _tone(_n(7 + i * 2), 0.1, at: i * 0.05, vol: 0.12);
      }
    case 'gambleLose':
      _tone(300, 0.3, slide: 120, type: 'triangle', vol: 0.15);
    case 'freeze':
      for (var i = 0; i < 5; i++) {
        _tone(_n(24 + i * 3), 0.3, at: i * 0.03, type: 'sine', vol: 0.08);
      }
    case 'jackpot':
      for (var i = 0; i < 10; i++) {
        _tone(_n(12 + (i % 3) * 4), 0.08, at: i * 0.05, vol: 0.1);
      }
    case 'condemn':
      _tone(880, 0.12, vol: 0.12);
      _tone(660, 0.2, at: 0.13, vol: 0.12);
    case 'upgrade':
      _tone(_n(3), 0.1, type: 'triangle', vol: 0.12);
      _tone(_n(10), 0.15, at: 0.06, type: 'triangle', vol: 0.12);
  }
}

// ---------------- Music: a wonky 3/4 waltz ----------------
Timer? _musicTimer;
bool _tense = false;
double _nextBar = 0;
int _bar = 0;

const _chords = [
  [-24, -12, -9, -5],
  [-24, -12, -9, -5],
  [-31, -19, -15, -12],
  [-28, -16, -13, -9],
  [-24, -12, -9, -5],
  [-29, -17, -14, -10],
  [-31, -19, -15, -12],
  [-28, -16, -12, -9],
];
const _melody = [
  [12, 11, 12], [16, 15, 12], [17, 14, 10], [11, 8, 4],
  [12, 9, 12], [17, 16, 14], [14, 12, 10], [8, 11, 14],
];

void music(bool on, bool tense) {
  final c = _c();
  if (c == null) return;
  _tense = tense;
  try {
    final bus = _musicBus!;
    final t = c.currentTime;
    bus.gain.setValueAtTime(on ? 0.0001 : 0.5, t);
    bus.gain.linearRampToValueAtTime(on ? 0.5 : 0.0001, t + 0.8);
  } catch (_) {}
  if (on && _musicTimer == null) {
    _nextBar = c.currentTime + 0.2;
    _musicTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _schedule());
  } else if (!on) {
    _musicTimer?.cancel();
    _musicTimer = null;
  }
}

void _schedule() {
  final c = _c();
  if (c == null) return;
  try {
    final beat = _tense ? 0.32 : 0.42;
    if (_nextBar < c.currentTime) _nextBar = c.currentTime + 0.05;
    while (_nextBar < c.currentTime + 1.2) {
      final i = _bar % _chords.length;
      final ch = _chords[i];
      final at = _nextBar - c.currentTime;
      final bus = _musicBus!;
      _tone(_n(ch[0]), beat * 0.9, type: 'triangle', vol: 0.22, at: at, out: bus);
      for (var b = 1; b < 3; b++) {
        for (final s in ch.sublist(1)) {
          _tone(_n(s), beat * 0.5, type: 'square', vol: 0.025, at: at + b * beat, out: bus);
        }
      }
      final mel = _melody[i];
      for (var k = 0; k < 3; k++) {
        final wob = (_bar ~/ 8) % 2 == 1 && k == 2 ? 1 : 0;
        _tone(_n(mel[k] - 12 + wob), beat * 0.85, type: 'sine', vol: 0.06, at: at + k * beat, out: bus);
        _tone(_n(mel[k] + wob) * 1.003, beat * 0.85, type: 'triangle', vol: 0.035, at: at + k * beat, out: bus);
      }
      if (_tense) _noiseBurst(0.05, vol: 0.04, freq: 6000, type: 'highpass', at: at);
      _nextBar += beat * 3;
      _bar++;
    }
  } catch (_) {}
}
