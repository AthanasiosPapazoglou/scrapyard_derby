import 'package:flutter/material.dart';

import '../game/derby_game.dart';
import '../game/landing.dart';

/// Small text panel with live tuning info.
class DebugOverlay extends StatelessWidget {
  const DebugOverlay({super.key, required this.info});

  final HudInfo info;

  @override
  Widget build(BuildContext context) {
    final landing = info.lastLanding;
    final landingColor = switch (landing) {
      LandingType.clean => Colors.greenAccent,
      LandingType.oneFoot => Colors.amberAccent,
      LandingType.crash => Colors.redAccent,
      null => Colors.white70,
    };
    const style = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontFamily: 'Menlo',
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: style,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.headLaunched
                  ? 'limbs  0/4, head launched'
                  : 'limbs  ${info.limbsLeft}/4',
            ),
            Text('speed  ${info.speed.toStringAsFixed(1)} m/s'),
            Text('spin   ${_spinLabel(info.spin)}'),
            Text(
              'energy ${info.spinEnergy.toStringAsFixed(1)}/'
              '${info.spinEnergyMax.toStringAsFixed(1)} turns',
            ),
            Text(
              'land   ${landing?.label ?? '-'}',
              style: style.copyWith(color: landingColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// e.g. "↻ 100%" for full clockwise, "↺ 40%" for slow counter-clockwise.
String _spinLabel(double spin) {
  final arrow = spin >= 0 ? '↻' : '↺';
  return '$arrow ${(spin.abs() * 100).round()}%';
}
