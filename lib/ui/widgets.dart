import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art.dart';

class LaneMeter extends StatelessWidget {
  final int count;
  final int limit;
  const LaneMeter({super.key, required this.count, required this.limit});
  @override
  Widget build(BuildContext context) {
    final f = (count / limit).clamp(0.0, 1.0);
    final col = Color.lerp(const Color(0xFF4FB286), Pal.danger, f)!;
    final style = TextStyle(color: f > 0.7 ? Pal.danger : Colors.white60, fontSize: 11, fontWeight: FontWeight.w800);
    // On narrow phones the words go and the numbers stay.
    return LayoutBuilder(builder: (context, c) {
      return Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(children: [
              Container(height: 10, color: Colors.black38),
              FractionallySizedBox(widthFactor: f, child: Container(height: 10, color: col)),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        Text(c.maxWidth >= 190 ? '$count/$limit on the pier' : '$count/$limit', style: style),
      ]);
    });
  }
}

class CurrencyChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  const CurrencyChip({super.key, required this.icon, required this.color, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
      );
}

class SpeechBubble extends StatelessWidget {
  final String speaker;
  final String text;
  const SpeechBubble({super.key, required this.speaker, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Pal.cream,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: [
              TextSpan(text: '$speaker: ', style: const TextStyle(color: Color(0xFFB0306A), fontWeight: FontWeight.w900, fontSize: 13)),
              TextSpan(text: text, style: const TextStyle(color: Pal.ink, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class BigBanner extends StatelessWidget {
  final String title;
  final String sub;
  final double k; // seconds left
  const BigBanner({super.key, required this.title, required this.sub, required this.k});
  @override
  Widget build(BuildContext context) {
    final a = k.clamp(0.0, 0.4) / 0.4;
    final scale = 1 + math.max(0, k - 2.0) * 0.4;
    return Opacity(
      opacity: a,
      child: Transform.scale(
        scale: scale.clamp(1.0, 1.3),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Pal.neon, width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Pal.neon, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
            if (sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }
}

class ToastPill extends StatelessWidget {
  final String text;
  const ToastPill({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xEE2A0F22), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class ActionBtn extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const ActionBtn({super.key, required this.label, required this.sub, required this.color, this.enabled = true, required this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.7))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
          ),
        ),
      );
}

class SummonButton extends StatelessWidget {
  final int cost;
  final bool enabled;
  final bool glow;
  final VoidCallback onTap;
  const SummonButton({super.key, required this.cost, required this.enabled, required this.onTap, this.glow = false});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: enabled ? const [Color(0xFFFFD34D), Color(0xFFFF8A3D)] : const [Color(0xFF5A5468), Color(0xFF443E52)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(color: glow ? Pal.neon : Colors.black54, blurRadius: glow ? 16 : 4, offset: const Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Center(
                child: Semantics(
                  label: 'Summon a figurine, $cost pennies${enabled ? '' : ', not available now'}',
                  excludeSemantics: true,
                  child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('SUMMON', style: TextStyle(color: enabled ? Pal.ink : Colors.white54, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.circle, size: 11, color: enabled ? const Color(0xFF8A4B00) : Colors.white38),
                const SizedBox(width: 3),
                Text('$cost', style: TextStyle(color: enabled ? const Color(0xFF5A3000) : Colors.white54, fontWeight: FontWeight.w900, fontSize: 13)),
              ]),
            ]),
                ),
                ),
              ),
            ),
          ),
        ),
      );
}

class SmallCtl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  const SmallCtl({super.key, required this.icon, required this.label, required this.color, this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Pal.panel2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Stack(clipBehavior: Clip.none, children: [
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 2),
                  FittedBox(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5))),
                ]),
              ),
              if (badge != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Pal.danger, borderRadius: BorderRadius.circular(10)),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class WideBtn extends StatelessWidget {
  final String title;
  final String sub;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const WideBtn({super.key, required this.title, required this.sub, required this.color, this.enabled = true, required this.onTap});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Pal.panel2,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: color, width: 4))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ]),
                ),
                Icon(Icons.chevron_right, color: color),
              ]),
            ),
          ),
        ),
      );
}

class MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool primary;
  final String? sub;
  const MenuButton({super.key, required this.label, required this.onTap, this.danger = false, this.primary = false, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SizedBox(
          width: 300,
          child: Material(
            color: primary ? Pal.neon : (danger ? const Color(0xFF4A1530) : Pal.panel2),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                child: Column(children: [
                  Text(label,
                      style: TextStyle(
                          color: primary ? Pal.ink : (danger ? Pal.danger : Colors.white), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                  if (sub != null)
                    Text(sub!, style: TextStyle(color: primary ? const Color(0xAA141018) : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      );
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Pal.panel2, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      );
}
