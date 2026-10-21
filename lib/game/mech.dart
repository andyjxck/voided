part of 'sim.dart';

/// A telegraphed attack: a ring on the ground (or a cell) that fills over
/// the wind-up, with a label above it. Every boss and elite move that can
/// hurt you gets one, and each is also read out by the screen reader.
class Tell {
  final String label;
  final int color;
  final double x, y, r;
  final int side, cell;
  final double dur;
  double t = 0;
  Tell(
    this.label, {
    this.color = 0xFFFFD166,
    this.x = -1,
    this.y = -1,
    this.r = 0.6,
    this.side = -1,
    this.cell = -1,
    this.dur = 2,
  });
  double get frac => (t / dur).clamp(0.0, 1.0);
  bool get done => t >= dur;
}

/// Hit kinds, for the Shadow Keeper and the Mirrorling.
const int kHitSingle = 0, kHitArea = 1, kHitStatus = 2;

extension _Mech on Game {
  // ------------------------------------------------------------------
  // Visibility and targeting rules
  // ------------------------------------------------------------------
  bool get _lampLane =>
      sides.any((p) => p.activeUnions().contains('Lamp') && p.unionSize('Lamp') >= 5) ||
      sides.any((p) => p.allUnits.any((u) => u.def.abil == Abil.beacon));

  bool _isLit(Enemy e) => e.litT > 0 || _lampAll;

  bool _inFog(Enemy e) {
    if (fogT <= 0) return false;
    final f = (e.s % field.lap) / field.lap;
    final d = (f - fogA) % 1.0;
    return d >= 0 && d < 1 / 3;
  }

  /// Whether figurine [d] on side [p] at [pos] may pick [e] as a target.
  bool _canTarget(Enemy e, UnitDef? d, PlayerSide? p, V2 pos) {
    if (e.dead) return false;
    final deep = d != null &&
        (d.abil == Abil.diver ||
            (d.tags.contains('Sea') && p != null && p.unionSize('Sea') >= 5 &&
                p.activeUnions().contains('Sea')));
    if (e.submerged && !deep) return false;
    if (e.tunnelT > 0 && !deep) return false;
    if (e.boss?.mech == BossMech.ghosttrain && e.carriages > 0 && e.def == null) {
      // the engine itself: only its rear carriage can be hit
      return false;
    }
    final lamp = d != null && (d.tags.contains('Lamp') || d.abil == Abil.beam);
    if (e.trait == Trait.hidden || e.copied == Trait.hidden) {
      final shown = e.revealT > 0 || _isLit(e);
      if (!shown && !lamp && !deep) return false;
    }
    if (_inFog(e) && !lamp && d != null && d.chain == 0) {
      if (field.at(e).dist(pos) > 3.0) return false;
    }
    // The Void's event horizon: only area and Lamp hits land inside it.
    final v = _voidBoss;
    if (v != null && e != v && d != null && !lamp && d.splash <= 0 && !d.pulse && d.chain == 0) {
      if (field.at(e).dist(field.at(v)) < 1.4) return false;
    }
    return true;
  }

  Enemy? get _voidBoss {
    for (final b in bossList) {
      if (!b.dead && b.boss!.mech == BossMech.voidboss) return b;
    }
    return null;
  }

  /// How likely [e] is to dodge a hit from [d].
  double _dodge(Enemy e, UnitDef? d) {
    if (e.inkT > 0 || _isLit(e)) return 0;
    if (d != null && (d.tags.contains('Lamp') || d.abil == Abil.beam)) return 0;
    var ev = e.evade;
    if (e.copied == Trait.dodge) ev = math.max(ev, 0.3);
    if (_inFog(e) && (d == null || d.chain == 0)) ev += 0.2;
    return ev.clamp(0.0, 0.85);
  }

  double _armorOf(Enemy e) {
    var a = e.armor;
    if (e.trait == Trait.grow) {
      a = math.min(0.6, (e.traveled % field.cycle) / field.cycle * 0.6);
    }
    if (e.copied == Trait.armor) a = math.max(a, 0.3);
    if (e.trait == Trait.tin && e.tin) a = math.max(a, 0.6);
    if (e.trait == Trait.puff) a = math.max(a, e.puff);
    if (e.clampT > 0) a = math.max(a, 0.7);
    if (e.stripT > 0) a *= 0.7;
    return a.clamp(0.0, 0.9);
  }

  bool _statusImmune(Enemy e) =>
      e.trait == Trait.nullify || e.immuneT > 0 || e.copied == Trait.nullify;

  /// Bruiser Crabs count control; at three they shrug it off for 6s.
  bool _controlBlocked(Enemy e) {
    if (_statusImmune(e)) return true;
    if (e.trait == Trait.bruiser) {
      e.stacks++;
      if (e.stacks >= 3) {
        e.stacks = 0;
        e.immuneT = 6;
        final p = field.at(e);
        fx.add(Fx(FxType.text, x: p.x, y: p.y, text: 'SHRUG', color: 0xFFFF8C42));
      }
    }
    return false;
  }

  // ------------------------------------------------------------------
  // Per-tick mechanics
  // ------------------------------------------------------------------
  void _mechTick(double dt) {
    for (final tl in tells) {
      tl.t += dt;
    }
    tells.removeWhere((tl) => tl.t > tl.dur + 0.4);
    if (bondsCut > 0) bondsCut -= dt;
    _lampAll = _lampLane;
    for (final p in sides) {
      for (final c in p.cells) {
        if (c.disabled > 0) c.disabled -= dt;
        if (c.protectT > 0) c.protectT -= dt;
        if (c.inkT > 0) c.inkT -= dt;
        if (c.flashT > 0) c.flashT -= dt;
        if (c.beamT > 0) c.beamT -= dt;
      }
      // crossed-out unions
      p.redacted.removeWhere((k, v) => v <= 0);
      for (final k in p.redacted.keys.toList()) {
        p.redacted[k] = p.redacted[k]! - dt;
      }
    }
    condemned.removeWhere(
      (side, cell) => sides[side].cells[cell].disabled <= 0,
    );
    _levelRule(dt);
    _abilities(dt);
    _claw(dt);
    if (lanternT > 0) {
      lanternT -= dt;
      if (lanternT <= 0) lanternHits = 0;
    }
  }

  void _levelRule(double dt) {
    final rule = levelDef(cfg.level).rule;
    switch (rule) {
      case LevelRule.fog:
        if (fogT > 0) fogT -= dt;
      case LevelRule.beam:
        beamT -= dt;
        if (beamT <= 2 && !beamWarned) {
          beamWarned = true;
          tell('The beam is coming round', dur: 2, color: 0xFFFFF3B0);
        }
        if (beamT <= 0) {
          beamT = 10;
          beamWarned = false;
          beamHalf = 1 - beamHalf;
          for (final p in sides) {
            for (var i = 0; i < p.cells.length; i++) {
              if ((i % kBoardCols < kBoardCols ~/ 2) == (beamHalf == 0)) {
                p.cells[i].beamT = 3;
              }
            }
          }
          // the beam lights everything on the near half of the lane
          for (final e in enemies) {
            if (((e.s % field.lap) / field.lap < 0.5) == (beamHalf == 0)) {
              e.litT = math.max(e.litT, 3);
            }
          }
          fx.add(Fx(FxType.pulse, x: field.w / 2, y: field.h / 2, size: field.w, color: 0x55FFF3B0));
        }
      default:
        break;
    }
  }

  /// Speed multiplier from the level rule for an enemy at lane position s.
  double _ruleSpeed(Enemy e) {
    final f = (e.s % field.lap) / field.lap;
    switch (levelDef(cfg.level).rule) {
      case LevelRule.tide:
        if (f < 0.5) return tideHigh ? 1.15 : 0.85;
        return 1;
      case LevelRule.rides:
        if ((f > 0.12 && f < 0.27) || (f > 0.62 && f < 0.77)) return 1.3;
        return 1;
      default:
        return 1;
    }
  }

  /// Called when a wave starts: level-rule events for that wave.
  void _ruleWave(int n) {
    final rule = levelDef(cfg.level).rule;
    if (rule == LevelRule.tide) {
      tideHigh = n.isEven;
      tell(tideHigh ? 'High tide this wave' : 'Low tide this wave', dur: 2.5, color: 0xFF4CC9F0);
    }
    if (rule == LevelRule.fog && n % 3 == 0) {
      fogA = rng.nextDouble();
      fogT = 8 + 2; // 2s of warning, 8s of fog
      tell('Fog rolling in', dur: 2, color: 0xFFB8C0C8);
    }
    if (rule == LevelRule.statik && n % 10 == 1 && n > 1) {
      for (final p in sides) {
        final flick = [for (var i = 0; i < p.cells.length; i++) if (p.cells[i].flicker > 0) i];
        for (final i in flick) {
          if (p.cells[i].flicker <= n) p.cells[i].flicker = 0;
        }
        final now = p.cells.where((c) => c.flicker > 0).length;
        if (now < 2) {
          final i = rng.nextInt(p.cells.length);
          p.cells[i].flicker = n + 10;
          tell('Static on a cell for 10 waves', side: p.index, cell: i, dur: 2.5, color: 0xFFC77DFF);
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // Figurine abilities that run on their own clock
  // ------------------------------------------------------------------
  void _abilities(double dt) {
    for (final e in enemies) {
      if (e.litT > 0) e.litT -= dt;
      if (e.revealT > 0) e.revealT -= dt;
    }
    for (final p in sides) {
      final unions = p.activeUnions();
      for (var ci = 0; ci < p.cells.length; ci++) {
        final c = p.cells[ci];
        if (c.isEmpty || !_cellWorks(c)) continue;
        final d = c.def!;
        final pos = field.cellCenter(p.index, ci);
        if (d.abil == Abil.reveal ||
            (d.tags.contains('Lamp') && unions.contains('Lamp'))) {
          for (final e in enemies) {
            if (!e.dead && field.at(e).dist(pos) <= d.range) {
              e.revealT = math.max(e.revealT, 0.3);
            }
          }
        }
        if (d.abil == Abil.lighter) {
          for (final e in enemies) {
            if (!e.dead && field.at(e).dist(pos) <= d.range) {
              e.litT = math.max(e.litT, 0.3);
            }
          }
        }
        if (d.abilEvery <= 0) continue;
        final u = c.units.first;
        u.abilT += dt;
        if (u.abilT < d.abilEvery) continue;
        u.abilT = 0;
        _fireAbility(p, ci, d, pos, unions);
      }
    }
  }

  bool _cellWorks(Cell c) =>
      !(c.disabled > 0 && c.protectT <= 0) && !(c.moths > 0 && c.protectT <= 0);

  void _fireAbility(PlayerSide p, int ci, UnitDef d, V2 pos, Set<String> unions) {
    final m = dmgMult(p, d);
    switch (d.abil) {
      case Abil.band:
        for (var i = 0; i < p.cells.length; i++) {
          if (field.cellCenter(p.index, i).dist(pos) < 1.5) {
            p.cells[i].protectT = math.max(p.cells[i].protectT, d.abilDur);
            if (p.cells[i].disabled > 0) p.cells[i].disabled = 0;
          }
        }
        fx.add(Fx(FxType.text, x: pos.x, y: pos.y, text: 'OOM-PAH', color: d.color));
      case Abil.horn:
        var any = false;
        for (final e in enemies) {
          if (e.dead || field.at(e).dist(pos) > d.range) continue;
          if (e.boss?.mech == BossMech.limpet && e.clampT > 0) continue;
          final back = e.isBoss ? 0.2 : d.abilPow;
          e.s -= back;
          e.traveled = math.max(0, e.traveled - back);
          any = true;
        }
        if (any) {
          fx.add(Fx(FxType.pulse, x: pos.x, y: pos.y, size: d.range, color: d.color));
        }
      case Abil.chime:
        final ts = _targets(pos, d.range, 1, by: d, side: p);
        if (ts.isEmpty) return;
        final at = field.at(ts.first);
        for (final e in enemies) {
          if (e.dead || field.at(e).dist(at) > 1.2) continue;
          if (_controlBlocked(e)) continue;
          e.freezeT = math.max(e.freezeT, e.isBoss ? 0.3 : d.abilDur);
        }
        fx.add(Fx(FxType.pulse, x: at.x, y: at.y, size: 1.2, color: 0xFFBDE0FE));
      case Abil.caramel:
        for (final e in enemies) {
          if (e.dead) continue;
          e.shield = 0;
          e.shellHits = 0;
          e.tin = false;
          e.stickyT = math.max(e.stickyT, d.abilDur + 1);
          if (_controlBlocked(e)) continue;
          e.freezeT = math.max(e.freezeT, e.isBoss ? 0.6 : d.abilDur);
        }
        fx.add(Fx(FxType.freeze, color: 0xFFFFA62B));
      case Abil.evict:
        final front = enemies.where((e) => !e.dead && !e.isBoss && e.def?.id != 'husk').toList()
          ..sort((a, b) => b.traveled.compareTo(a.traveled));
        for (final e in front.take(d.abilPow.round())) {
          final back = e.traveled % field.lap;
          e.s -= back;
          e.traveled -= back;
          final ep = field.at(e);
          fx.add(Fx(FxType.text, x: ep.x, y: ep.y, text: 'EVICTED', color: d.color));
        }
      case Abil.ink:
        final ts = _targets(pos, d.range, 1, by: d, side: p);
        if (ts.isEmpty) return;
        final at = field.at(ts.first);
        for (final e in [...enemies]) {
          if (e.dead || field.at(e).dist(at) > 1.5) continue;
          e.inkT = math.max(e.inkT, d.abilDur);
          e.noHealT = math.max(e.noHealT, d.abilDur);
          _damage(e, d.dmg * d.abilPow * m, p, unit: d, canEvade: false, quiet: true, kind: kHitArea);
        }
        fx.add(Fx(FxType.pulse, x: at.x, y: at.y, size: 1.5, color: 0xFF2E4057));
      case Abil.train:
        final cars = math.max(1, unions.length);
        for (final e in [...enemies]) {
          if (e.dead || e.submerged) continue;
          _damage(e, d.dmg * d.abilPow * cars * m, p, unit: d, canEvade: false, quiet: true, kind: kHitArea);
        }
        fx.add(Fx(FxType.text, x: pos.x, y: pos.y, text: 'ALL ABOARD x$cars', color: d.color));
      case Abil.erase:
        Enemy? best;
        for (final e in enemies) {
          if (e.dead || field.at(e).dist(pos) > d.range + 1) continue;
          if (e.isBoss) continue;
          if (best == null || e.hp > best.hp) best = e;
        }
        if (best != null) {
          _damage(best, best.hp + best.shield + 1, p, unit: d, canEvade: false, ignoreArmor: true, quiet: true, kind: kHitStatus);
          final bp = field.at(best);
          fx.add(Fx(FxType.text, x: bp.x, y: bp.y, text: 'ERASED', color: d.color));
        } else if (boss != null && !boss!.dead) {
          _damage(boss!, boss!.maxHp * d.abilPow, p, unit: d, canEvade: false, ignoreArmor: true, quiet: true, kind: kHitStatus);
        }
      default:
        break;
    }
  }

  /// Damage multiplier from content figurines and marks, for a hit by [d]
  /// from cell [ci] of side [p] on [e].
  double _hitMult(PlayerSide p, int ci, UnitDef d, Enemy e) {
    var m = 1.0;
    if (e.litT > 0) m *= 1.1;
    if (e.markT > 0) m *= 1 + e.markPct;
    final unions = p.activeUnions();
    if (unions.contains('Sweets') && p.unionSize('Sweets') >= 5 && e.slowT > 0) m *= 1.1;
    if (d.tags.contains('Staff') && unions.contains('Staff') && p.unionSize('Staff') >= 5) {
      m *= 1.35 / 1.2;
    }
    if (d.tags.contains('Lamp') && unions.contains('Lamp') && p.unionSize('Lamp') >= 5) m *= 1.2;
    // The Beacon's light.
    if (ci >= 0) {
      final me = field.cellCenter(p.index, ci);
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (c.def?.abil == Abil.beacon && _cellWorks(c) &&
            field.cellCenter(p.index, i).dist(me) <= c.def!.range) {
          m *= 1 + c.def!.abilPow;
          break;
        }
      }
    }
    return m;
  }

  /// After a hit lands: the on-hit effects of the new figurines.
  void _onHit(PlayerSide p, UnitInst u, UnitDef d, Enemy t) {
    switch (d.abil) {
      case Abil.sticky:
        t.stickyT = math.max(t.stickyT, d.abilDur);
      case Abil.shatter:
        u.hits++;
        if (u.hits % d.abilEvery.round() == 0) {
          t.shield = 0;
          t.shellHits = 0;
          t.tin = false;
          t.puff = 0;
          final tp = field.at(t);
          fx.add(Fx(FxType.text, x: tp.x, y: tp.y, text: 'CRACK', color: d.color));
        }
      case Abil.watch:
        t.noHealT = math.max(t.noHealT, d.abilDur);
        t.markT = math.max(t.markT, d.abilDur);
        t.markPct = math.max(t.markPct, d.abilPow);
      case Abil.crown:
        t.stripT = math.max(t.stripT, 4);
      default:
        break;
    }
    if (t.trait == Trait.puff) t.puff = math.min(0.5, t.puff + 0.05);
  }

  // ------------------------------------------------------------------
  // Enemy traits, per tick
  // ------------------------------------------------------------------
  /// Returns a speed multiplier for this tick.
  double _traitTick(Enemy e, double dt) {
    if (e.stickyT > 0) e.stickyT -= dt;
    if (e.noHealT > 0) e.noHealT -= dt;
    if (e.markT > 0) e.markT -= dt;
    if (e.inkT > 0) e.inkT -= dt;
    if (e.stripT > 0) e.stripT -= dt;
    if (e.immuneT > 0) e.immuneT -= dt;
    if (e.tunnelT > 0) e.tunnelT -= dt;
    if (e.clampT > 0) e.clampT -= dt;
    if (e.puff > 0) e.puff = math.max(0, e.puff - 0.08 * dt);
    if (_statusImmune(e)) {
      e.slowPct = 0;
      e.slowT = 0;
      e.stunT = 0;
      e.freezeT = 0;
      if (e.trait == Trait.nullify) {
        e.burnT = 0;
        e.curseT = 0;
      }
    }
    var sp = _ruleSpeed(e);
    final tr = e.copied != Trait.none ? e.copied : e.trait;
    e.traitT += dt;
    switch (e.trait) {
      case Trait.spender:
        break;
      case Trait.castle:
        if (e.traitT >= e.def!.every) {
          e.traitT = 0;
          for (var i = 0; i < 2; i++) {
            _spawnScaled('pinchy', e, e.s - 0.3 * (i + 1), e.traveled);
          }
        }
      case Trait.ram:
        if (e.traitT >= e.def!.every - 1 && !e.rammed) {
          e.rammed = true;
          final ep = field.at(e);
          tell('Dodgem revving', x: ep.x, y: ep.y, r: 0.5, dur: 1, color: 0xFFE63946, alert: false);
        }
        if (e.traitT >= e.def!.every) {
          e.traitT = 0;
          e.rammed = false;
          if (e.stickyT <= 0 && e.stunT <= 0 && e.freezeT <= 0) {
            for (final o in enemies) {
              if (o.dead || o.route != e.route || (o.s - e.s).abs() > 1.0) continue;
              o.s += 0.5;
              o.traveled += 0.5;
            }
            final ep = field.at(e);
            fx.add(Fx(FxType.text, x: ep.x, y: ep.y, text: 'RAM', color: 0xFFE63946));
          }
        }
      case Trait.blink:
        if (e.traitT >= 4) {
          e.traitT = 0;
          if (e.stickyT <= 0 && e.stunT <= 0) {
            e.s += 1.2;
            e.traveled += 1.2;
          }
        }
      case Trait.foghorn:
        if (e.traitT >= e.def!.every - 2 && !e.rammed) {
          e.rammed = true;
          final ep = field.at(e);
          tell('Fog Horn swelling', x: ep.x, y: ep.y, r: 1.2, dur: 2, color: 0xFF8D6E63);
        }
        if (e.traitT >= e.def!.every) {
          e.traitT = 0;
          e.rammed = false;
          for (final o in enemies) {
            if (o.dead) continue;
            o.slowT = 0;
            o.slowPct = 0;
            o.stunT = 0;
            o.freezeT = 0;
            o.immuneT = math.max(o.immuneT, 3);
          }
          fx.add(Fx(FxType.shake, size: 0.5));
        }
      case Trait.moth:
        if (e.latchSide < 0 && e.traveled > 1.0) _mothLatch(e);
        if (e.latchSide >= 0) sp = 0.15;
      case Trait.echo:
        Enemy? ahead;
        for (final o in enemies) {
          if (o == e || o.dead || o.isBoss || o.traveled <= e.traveled) continue;
          if (ahead == null || o.traveled < ahead.traveled) ahead = o;
        }
        final at = ahead?.trait ?? Trait.none;
        e.copied = const {Trait.armor, Trait.dodge, Trait.heal, Trait.shell, Trait.hidden, Trait.nullify}.contains(at) ? at : Trait.none;
        if (e.copied == Trait.shell && e.shellHits == 0 && !e.shellUsed) {
          e.shellHits = 3;
          e.shellUsed = true;
        }
      default:
        break;
    }
    if (tr == Trait.heal || (e.copied == Trait.heal)) {
      for (final o in enemies) {
        if (o == e || o.dead || o.isBoss || o.noHealT > 0 || o.burnT > 0) continue;
        // Heals don't stack: one healer per thing per moment.
        if (o.healedAt == time) continue;
        if (o.route == e.route && (o.s - e.s).abs() < 1.3) {
          o.healedAt = time;
          o.hp = math.min(o.maxHp, o.hp + o.maxHp * 0.02 * dt);
        }
      }
    }
    // Big Spender: everything is faster while you are rich.
    if (spenderAlive) {
      final rich = sides.map((p) => p.pennies).reduce(math.max);
      sp *= 1 + math.min(0.3, 0.05 * (rich ~/ 50));
    }
    // Lady Limpet: everything else is faster while she is clamped.
    if (limpetClamped && !(e.boss?.mech == BossMech.limpet)) sp *= 1.3;
    if (e.trait == Trait.pony && e.group >= 0) {
      sp *= 1 + 0.25 * (ponyLost[e.group] ?? 0);
    }
    if (e.clampT > 0) sp = 0;
    return sp;
  }

  void _mothLatch(Enemy e) {
    var bestSide = -1, bestCell = -1;
    var bestPow = -1.0;
    for (final p in sides) {
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (c.isEmpty || c.moths > 0) continue;
        final pow = c.def!.dmg * c.units.length / c.def!.interval;
        if (pow > bestPow) {
          bestPow = pow;
          bestSide = p.index;
          bestCell = i;
        }
      }
    }
    if (bestSide < 0) return;
    final cell = sides[bestSide].cells[bestCell];
    if (cell.protectT > 0 || _crowned(bestSide, bestCell)) return;
    e.latchSide = bestSide;
    e.latchCell = bestCell;
    cell.moths++;
    final cc = field.cellCenter(bestSide, bestCell);
    // the moth sits on the cell: move it there visually by parking it
    fx.add(Fx(FxType.text, x: cc.x, y: cc.y, text: 'MOTH', color: 0xFF9C8C74));
    alerts.add('A Lampmoth has landed on ${cell.def!.name}. Kill it to free them.');
  }

  bool _crowned(int side, int cell) {
    final p = sides[side];
    final me = field.cellCenter(side, cell);
    for (var i = 0; i < p.cells.length; i++) {
      if (p.cells[i].def?.abil == Abil.crown &&
          i != cell &&
          field.cellCenter(side, i).dist(me) < 1.5) {
        return true;
      }
    }
    return false;
  }

  /// Whether a cell is shielded from being disabled.
  bool _cellSafe(int side, int cell) =>
      sides[side].cells[cell].protectT > 0 || _crowned(side, cell);

  /// A lap finished: lap-end traits.
  void _onLap(Enemy e) {
    switch (e.trait) {
      case Trait.thief:
        for (final p in sides) {
          final take = math.min(2, p.pennies);
          p.pennies -= take;
          e.stolen += take;
        }
        final ep = field.at(e);
        fx.add(Fx(FxType.text, x: ep.x, y: ep.y, text: '-2p', color: 0xFFFF5E7E));
      case Trait.bigtop:
        final pool = enemyPool(wave, cfg.level).where((id) => !kDisruptive.contains(id)).toList();
        for (var i = 0; i < 2; i++) {
          _spawnScaled(pool[rng.nextInt(pool.length)], e, e.s - 0.3 * (i + 1), e.traveled);
        }
        tell('The Big Top lets out two more', dur: 1.5, alert: true);
      case Trait.unmaker:
        if (unmadeThisWave > 0) return;
        _unmake();
      default:
        break;
    }
  }

  void _unmake() {
    PlayerSide? who;
    var bi = -1;
    for (final p in sides) {
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (c.isEmpty || c.def!.tier == Tier.mythic) continue;
        if (bi < 0 || c.def!.tier.index < who!.cells[bi].def!.tier.index) {
          who = p;
          bi = i;
        }
      }
    }
    if (who == null) return;
    unmadeThisWave++;
    final c = who.cells[bi];
    final name = c.def!.name;
    c.units.removeLast();
    final cc = field.cellCenter(who.index, bi);
    fx.add(Fx(FxType.text, x: cc.x, y: cc.y, text: 'UNMADE', color: 0xFF5A189A));
    alerts.add('The Unmaker erased a $name.');
  }

  /// Spawn an extra enemy mid-wave at this wave's health.
  Enemy _spawnScaled(String id, Enemy from, double s, double traveled) {
    final e = _spawn(id, route: from.route, s: s, traveled: traveled);
    return e;
  }

  // ------------------------------------------------------------------
  // Deaths
  // ------------------------------------------------------------------
  void _onDeath(Enemy e, UnitDef? unit, int kind) {
    final pos = field.at(e);
    if (e.latchSide >= 0) {
      final c = sides[e.latchSide].cells[e.latchCell];
      c.moths = math.max(0, c.moths - 1);
      e.latchSide = -1;
    }
    switch (e.trait) {
      case Trait.thief:
        for (final p in sides) {
          p.pennies += e.stolen ~/ sides.length + 1;
        }
      case Trait.ink:
        for (final o in enemies) {
          if (o == e || o.dead || o.route != e.route || (o.s - e.s).abs() > 1.0) continue;
          o.tunnelT = math.max(o.tunnelT, 1.5);
        }
        fx.add(Fx(FxType.pulse, x: pos.x, y: pos.y, size: 1.0, color: 0xFF1B1B3A));
      case Trait.flash:
        for (final p in sides) {
          final idx = List.generate(p.cells.length, (i) => i)
            ..sort((a, b) => field.cellCenter(p.index, a).dist(pos).compareTo(field.cellCenter(p.index, b).dist(pos)));
          for (final i in idx.take(2)) {
            p.cells[i].flashT = 2;
          }
        }
        fx.add(Fx(FxType.pulse, x: pos.x, y: pos.y, size: 1.6, color: 0xFFFFF3B0));
      case Trait.mirror:
        if (kind == kHitSingle && !e.isCopy) {
          for (var i = 0; i < 2; i++) {
            final c = _spawn('mirror', route: e.route, s: e.s - 0.2 * i, traveled: e.traveled);
            c.maxHp = e.maxHp * 0.3;
            c.hp = c.maxHp;
            c.isCopy = true;
          }
        }
      case Trait.pony:
        if (e.group >= 0) ponyLost[e.group] = (ponyLost[e.group] ?? 0) + 1;
      case Trait.pair:
        // its partner heals to full unless it dies within 2s
        for (final o in enemies) {
          if (o != e && !o.dead && o.pairId == e.pairId && e.pairId >= 0) {
            o.pairDue = time + 2;
          }
        }
      case Trait.spender:
        spenderAlive = enemies.any((o) => o != e && !o.dead && o.trait == Trait.spender);
      default:
        break;
    }
  }

  /// Star pairs: a partner left alive for 2s heals to full.
  void _pairCheck(Enemy e) {
    if (e.pairDue > 0 && time >= e.pairDue) {
      e.pairDue = 0;
      if (e.noHealT <= 0) e.hp = e.maxHp;
      final ep = field.at(e);
      fx.add(Fx(FxType.text, x: ep.x, y: ep.y, text: 'MENDED', color: 0xFFFFB4A2));
    }
  }

  // ------------------------------------------------------------------
  // Waves: what turns up
  // ------------------------------------------------------------------
  List<String> _composeWave(int n) {
    final lv = cfg.level;
    // Everything comes out of the Hatch in twins (one per route), so each
    // route gets half the wave's threat.
    final budget = math.max(2, (threatBudget(n, lv) * kTwinWaveShare).ceil());
    final pool = enemyPool(n, lv);
    final out = <String>[];
    int cost(String id) => kEnemyById[id]!.threat;
    final show = showcaseFor(n, lv);
    if (show != null) {
      // The showcase: the new thing alone with Seeps.
      final k = math.max(3, (budget * 0.4 / cost(show)).round());
      var spent = 0;
      for (var i = 0; i < k; i++) {
        out.add(show);
        spent += cost(show);
      }
      while (spent < budget) {
        out.add('drip');
        spent++;
      }
      out.shuffle(rng);
      return _cap(out);
    }
    // Up to four types, at most two of them disruptive, newer ones likelier.
    final roster = kLevelRoster[((lv - 1) % kLevels.length) + 1]!;
    final cands = [...pool]..sort((a, b) => (roster[b] ?? 0).compareTo(roster[a] ?? 0));
    final picked = <String>[];
    var disrupt = 0;
    for (final id in cands) {
      if (picked.length >= 4) break;
      if (id == 'drip') continue;
      if (kDisruptive.contains(id)) {
        if (disrupt >= 2) continue;
        disrupt++;
      }
      if (rng.nextDouble() < 0.7 || picked.length < 2) picked.add(id);
    }
    if (picked.isEmpty) picked.add('drip');
    picked.add('drip');
    // Squads, now and then, when the level has the members.
    var spent = 0;
    if (n % 4 == 2) {
      final ok = kSquads.where((sq) => sq.every((id) => id == 'wibble' ? pool.contains('wobbler') : pool.contains(id))).toList();
      if (ok.isNotEmpty) {
        final sq = ok[rng.nextInt(ok.length)];
        for (final id in sq) {
          out.add(id);
          spent += math.max(1, cost(id));
        }
      }
    }
    while (spent < budget) {
      final id = picked[rng.nextInt(picked.length)];
      if (id == 'pony') {
        for (var i = 0; i < 4; i++) {
          out.add('pony');
        }
        spent += 4 * cost(id);
        continue;
      }
      out.add(id);
      spent += math.max(1, cost(id));
    }
    out.shuffle(rng);
    // keep ponies together in fours
    final ponies = out.where((x) => x == 'pony').length;
    if (ponies > 0) {
      out.removeWhere((x) => x == 'pony');
      final at = rng.nextInt(out.length + 1);
      out.insertAll(at, List.filled(ponies, 'pony'));
    }
    return _cap(out);
  }

  /// No more than two moths at once; pairs of stars get tethered.
  List<String> _cap(List<String> l) {
    var moths = 0;
    for (var i = 0; i < l.length; i++) {
      if (l[i] == 'moth') {
        moths++;
        if (moths > 2) l[i] = 'drip';
      }
    }
    return l;
  }

  // ------------------------------------------------------------------
  // Bosses from the plan
  // ------------------------------------------------------------------
  double _mechRate(Enemy e) => e.form2 ? 0.7 : 1.0;

  void _bossMech2(Enemy e, double dt) {
    final b = e.boss!;
    final pos = field.at(e);
    switch (b.mech) {
      case BossMech.cuttle:
        // Ink Column: one column of a board gets half range.
        if (e.mechT <= 2 && e.pending < 0) {
          e.pending = rng.nextInt(kBoardCols);
          for (final p in sides) {
            tell('Ink column incoming', side: p.index, cell: e.pending, dur: 2, color: 0xFF1B1B3A);
          }
        }
        if (e.mechT <= 0) {
          e.mechT = 10 * _mechRate(e);
          final col = e.pending < 0 ? rng.nextInt(kBoardCols) : e.pending;
          e.pending = -1;
          for (final p in sides) {
            for (var r = 0; r < kBoardRows; r++) {
              final i = r * kBoardCols + col;
              if (!_cellSafe(p.index, i)) p.cells[i].inkT = 4;
            }
          }
          say(b.name, 'Ink in yer eyes!');
        }
        final frac = e.hp / e.maxHp;
        if ((e.phase == 0 && frac < 0.66) || (e.phase == 1 && frac < 0.33)) {
          e.phase++;
          for (var i = 0; i < 4; i++) {
            _spawn('thief', route: e.route, s: e.s - 0.4 * (i + 1), traveled: e.traveled);
          }
          say(b.name, 'Plunder! Take their pennies, lads!');
        }
      case BossMech.kingcrab:
        final frac = e.hp / e.maxHp;
        if (e.mechT <= 0) {
          e.mechT = 8;
          for (var i = 0; i < 2; i++) {
            _spawn('pinchy', route: e.route, s: e.s - 0.3 * (i + 1), traveled: e.traveled);
          }
        }
        if ((e.phase == 0 && frac < 0.66) || (e.phase == 1 && frac < 0.33)) {
          e.phase++;
          final h = _spawn('husk', route: e.route, s: e.s - 0.2, traveled: e.traveled);
          h.maxHp = e.maxHp * 0.12;
          h.hp = h.maxHp;
          e.surgeT = 8 * 0.4; // a short burst
          e.bareT = 8;
          tell('King Crabbington molts', x: pos.x, y: pos.y, r: 1, dur: 1.5, color: 0xFFBC4749);
          say(b.name, 'Behold my magnificent... soft... new self.');
        }
        if (e.bareT > 0) e.bareT -= dt;
      case BossMech.prizeclaw:
        if (clawSide < 0 && clawHeld == null && e.mechT <= 0) {
          e.mechT = 9 * _mechRate(e);
          _clawAim();
        }
        if (clawHeld != null) {
          if (e.hp < clawHp - e.maxHp * 0.15 || clawHold <= 0) _clawDrop();
        }
      case BossMech.limpet:
        if (e.clampT <= 0 && e.mechT <= 1.5 && e.pending < 0) {
          e.pending = 1;
          tell('Lady Limpet is about to clamp', x: pos.x, y: pos.y, r: 0.9, dur: 1.5, color: 0xFF6D597A);
        }
        if (e.mechT <= 0) {
          e.mechT = 10 * _mechRate(e);
          e.pending = -1;
          e.clampT = e.form2 ? 6 : 5;
          say(b.name, 'I. Will. Not. Be. Moved.');
        }
        limpetClamped = bossList.any((b) => !b.dead && b.clampT > 0);
      case BossMech.ringmaster:
        if (act == null && e.mechT <= 2) {
          const acts = ['Clowns', 'Lion', 'Knife Thrower'];
          act = acts[rng.nextInt(3)];
          tell('Next act: $act', x: pos.x, y: pos.y, r: 1, dur: 2, color: 0xFF9B2226);
          say(b.name, 'And now... the $act!');
        }
        if (e.mechT <= 0) {
          e.mechT = 12 * _mechRate(e);
          final a = act ?? 'Clowns';
          act = null;
          final times = e.form2 ? 2 : 1;
          for (var k = 0; k < times; k++) {
            if (a == 'Clowns') {
              for (var i = 0; i < 6; i++) {
                _spawn('clown', route: e.route, s: e.s - 0.25 * (i + 1), traveled: e.traveled);
              }
            } else if (a == 'Lion') {
              _spawn('lion', route: e.route, s: e.s - 0.4, traveled: e.traveled);
            } else {
              e.knifeMiss += 5;
            }
          }
        }
      case BossMech.wrecker:
        if (lanternT <= 0 && e.mechT <= 0) {
          e.mechT = 9 * _mechRate(e);
          lanternT = 3;
          lanternHits = e.form2 ? 12 : 8;
          lanternPos = V2(pos.x, pos.y);
          tell('False lantern lit', x: pos.x, y: pos.y, r: 0.7, dur: 3, color: 0xFFFFC300);
          say(b.name, 'This way, little ships...');
        }
      case BossMech.redactor:
        if (redactPending == null && e.mechT <= 2) {
          // pick the union the most players lean on
          final counts = <String, int>{};
          for (final p in sides) {
            for (final u in p.activeUnions()) {
              counts[u] = (counts[u] ?? 0) + p.unionSize(u);
            }
          }
          if (counts.isNotEmpty) {
            final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
            redactPending = top;
            tell('$top is about to be redacted', dur: 2, color: 0xFF212529);
          } else {
            e.mechT = 4;
          }
        }
        if (e.mechT <= 0) {
          e.mechT = 12 * _mechRate(e);
          final u = redactPending;
          redactPending = null;
          if (u != null) {
            for (final p in sides) {
              p.redacted[u] = e.form2 ? 10 : 8;
            }
            say(b.name, 'The $u union is ████████ for eight seconds.');
          }
        }
      case BossMech.ghosttrain:
        if (e.mechT <= 1 && e.pending < 0) {
          e.pending = 1;
          tell('Whistle! Into the tunnel', x: pos.x, y: pos.y, r: 1, dur: 1, color: 0xFF52B788);
        }
        if (e.mechT <= 0) {
          e.mechT = 15;
          e.pending = -1;
          e.tunnelT = 2;
          for (final c in enemies) {
            if (c.trainOf == e) c.tunnelT = 2;
          }
        }
        // keep carriages behind the engine
        var k = 1;
        for (final c in enemies) {
          if (c.dead || c.trainOf != e) continue;
          c.s = e.s - 0.45 * k;
          c.traveled = math.max(0, e.traveled - 0.45 * k);
          c.speed = 0;
          k++;
        }
      case BossMech.shadowkeeper:
        if (e.mechT <= 0) {
          e.mechT = 10;
          var bi = 0;
          for (var i = 1; i < 3; i++) {
            if (e.hurtBy[i] > e.hurtBy[bi]) bi = i;
          }
          e.resist = e.hurtBy.every((v) => v == 0) ? -1 : bi;
          e.hurtBy.fillRange(0, 3, 0);
          if (e.resist >= 0) {
            final what = const ['single-target', 'area', 'status'][e.resist];
            tell('The Shadow Keeper adapts to $what', x: pos.x, y: pos.y, r: 1, dur: 1.5, color: 0xFF7B2CBF);
          }
        }
        if (e.phase == 0 && e.hp / e.maxHp < 0.5) {
          e.phase = 1;
          _silenceStrongest(3, 5);
          say(b.name, 'Let the dark keep your best ones a while.');
        }
      case BossMech.voidboss:
        // Event Horizon: pull everything in the lane a little closer.
        for (final o in enemies) {
          if (o == e || o.dead || o.isBoss || o.route != e.route) continue;
          final dd = e.s - o.s;
          if (dd > 0 && dd < 3) {
            o.s += 0.15 * dt;
            o.traveled += 0.15 * dt;
          }
        }
        final frac = e.hp / e.maxHp;
        if (e.phase == 0 && frac < 0.66 && e.twinLead) {
          e.phase = 1;
          // replays every earlier final, weakened
          for (final id in ['landlord', 'cuttle', 'kingcrab', 'ghosttrain', 'shadowkeeper']) {
            final r = _spawnBoss(kBossById[id]!, scale: 0.12, s: e.s - 0.5, route: e.route);
            r.mechT = 4;
          }
          tell('The Void replays every final', dur: 2, color: 0xFF7B2CBF);
          say(b.name, 'Remember them?');
        }
        if (e.phase == 1 && frac < 0.25) {
          e.phase = 2;
          laneLimit = 80;
          tell('The Rift widens: limit now 80', dur: 2.5, color: 0xFFFF5E7E);
          say(b.name, 'More Rift. Same amount of you.');
        }
      default:
        break;
    }
  }

  void _silenceStrongest(int n, double dur) {
    final cells = <(int, int, double)>[];
    for (final p in sides) {
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (c.isEmpty || _cellSafe(p.index, i)) continue;
        cells.add((p.index, i, c.def!.dmg * c.units.length / c.def!.interval));
      }
    }
    cells.sort((a, b) => b.$3.compareTo(a.$3));
    for (final c in cells.take(n)) {
      sides[c.$1].cells[c.$2].disabled = dur;
      final cc = field.cellCenter(c.$1, c.$2);
      fx.add(Fx(FxType.condemn, x: cc.x, y: cc.y));
    }
  }

  // ---- the Prize Claw ----
  void _clawAim() {
    final opts = <(int, int)>[];
    for (final p in sides) {
      for (var i = 0; i < p.cells.length; i++) {
        final c = p.cells[i];
        if (c.isEmpty || c.def!.tier == Tier.mythic) continue;
        opts.add((p.index, i));
      }
    }
    if (opts.isEmpty) return;
    opts.sort((a, b) {
      final ca = sides[a.$1].cells[a.$2], cb = sides[b.$1].cells[b.$2];
      return (cb.def!.tier.index * 10 + cb.units.length).compareTo(ca.def!.tier.index * 10 + ca.units.length);
    });
    final pick = opts.first;
    clawSide = pick.$1;
    clawCell = pick.$2;
    clawT = 2;
    tell('The Claw is lining up', side: clawSide, cell: clawCell, dur: 2, color: 0xFFB0BEC5);
  }

  void _claw(double dt) {
    if (clawHeld != null) clawHold -= dt;
    if (clawSide < 0) return;
    clawT -= dt;
    if (clawT > 0) return;
    final p = sides[clawSide];
    final c = p.cells[clawCell];
    final b = boss;
    if (!c.isEmpty && c.def!.tier != Tier.mythic && !_cellSafe(clawSide, clawCell) && b != null && !b.dead) {
      clawHeld = c.units.removeLast();
      clawFrom = clawSide;
      clawHp = b.hp;
      clawHold = 12;
      say(b.name, 'Winner! You win... nothing. I win ${clawHeld!.def.name}.');
    }
    clawSide = -1;
    clawCell = -1;
  }

  void _clawDrop() {
    final u = clawHeld;
    if (u == null) return;
    clawHeld = null;
    final p = sides[clawFrom];
    final at = place(p, u.def);
    if (at < 0) {
      // no room: it comes back as pennies
      p.pennies += 20;
    }
    fx.add(Fx(FxType.text, x: field.w / 2, y: field.h / 2, text: 'DROPPED IT', color: 0xFFB0BEC5));
  }
}
