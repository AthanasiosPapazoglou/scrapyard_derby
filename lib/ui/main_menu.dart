import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../profile/player_profile.dart';
import 'game_page.dart';
import 'outlined_text.dart';

/// The first screen: title, best distance, scrap and Play.
///
/// A plain first version; roadmap step 2 adds the dusk scene, the idling
/// robot and the Workshop / Settings buttons.
class MainMenu extends StatelessWidget {
  const MainMenu({super.key, required this.profile});

  final PlayerProfile profile;

  void _play(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => GamePage(profile: profile)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.skyTop, Palette.skyMid, Palette.skyHorizon],
          ),
        ),
        child: SafeArea(
          child: Center(
            // Rebuilds when a run sets a new best or earns scrap.
            child: ListenableBuilder(
              listenable: profile,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const OutlinedText(
                    'SCRAPYARD DERBY',
                    fontSize: 48,
                    color: Palette.hazard,
                  ),
                  const SizedBox(height: 8),
                  OutlinedText(
                    'Best: ${profile.bestDistance.toStringAsFixed(0)} m'
                    '   Scrap: ${profile.scrap}',
                    fontSize: 18,
                    color: Palette.cream,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _play(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.hazard,
                      foregroundColor: Palette.outline,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 14,
                      ),
                      side: const BorderSide(color: Palette.outline, width: 3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
