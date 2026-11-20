import 'package:flutter/material.dart';

import '../game/levels.dart';
import '../game/palette.dart';
import '../game/races.dart';
import '../game/sound.dart';
import '../profile/player_profile.dart';
import 'derby_route.dart';
import 'layout.dart';
import 'level_select_page.dart';
import 'page_header.dart';
import 'still_scene.dart';
import 'versus_ladder_page.dart';

/// Opened with Play: pick Survival (the level ladder, your own upgrades)
/// or Versus (races against 3 rivals with given gear).
class ModeSelectPage extends StatelessWidget {
  const ModeSelectPage({super.key, required this.profile});

  final PlayerProfile profile;

  void _open(BuildContext context, Widget Function() page) {
    Sound.play(Sfx.uiClick);
    Navigator.of(context).push(DerbyRoute<void>(builder: (_) => page()));
  }

  @override
  Widget build(BuildContext context) {
    final survival = _ModeCard(
      title: 'SURVIVAL',
      icon: Icons.terrain,
      text:
          'Your robot, your upgrades. Go as far as you can down six endless '
          'hills and earn stars.',
      theme: LevelTheme.of(1),
      cameraX: 20,
      progress: (p) =>
          'Level ${p.highestUnlockedLevel} · '
          '${p.totalStars} / ${Levels.count * Levels.maxStars} stars',
      profile: profile,
      onTap: () => _open(context, () => LevelSelectPage(profile: profile)),
    );
    final versus = _ModeCard(
      title: 'VERSUS',
      icon: Icons.emoji_events,
      text:
          'Race 3 rivals down the same hill with the gear you are given. '
          'Win to climb the ladder.',
      theme: LevelTheme.of(4),
      cameraX: 140,
      progress: (p) =>
          'Race ${p.highestUnlockedRace} · '
          '${p.racesWon} / ${Races.count} won',
      profile: profile,
      onTap: () => _open(context, () => VersusLadderPage(profile: profile)),
    );
    return Scaffold(
      backgroundColor: Palette.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: StillScene(LevelTheme.of(1))),
          SafeArea(
            child: Column(
              children: [
                PageHeader(
                  title: 'PLAY',
                  onBack: () => Navigator.of(context).pop(),
                  trailing: [
                    ListenableBuilder(
                      listenable: profile,
                      builder: (context, _) => HeaderCount(
                        icon: Icons.settings,
                        text: '${profile.scrap}',
                        label: 'Scrap',
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: OrientationSwitch(
                      portrait: (context) => Column(
                        children: [
                          Expanded(child: survival),
                          const SizedBox(height: 14),
                          Expanded(child: versus),
                        ],
                      ),
                      landscape: (context) => Row(
                        children: [
                          Expanded(child: survival),
                          const SizedBox(width: 14),
                          Expanded(child: versus),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One mode: a window onto its scenery, the name, a line about it and the
/// player's progress.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.icon,
    required this.text,
    required this.theme,
    required this.cameraX,
    required this.progress,
    required this.profile,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String text;
  final LevelTheme theme;
  final double cameraX;
  final String Function(PlayerProfile profile) progress;
  final PlayerProfile profile;
  final VoidCallback onTap;

  static const _ink = Palette.outline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: Palette.cream,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _ink, width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: CustomPaint(
                  painter: StillScene(theme, cameraX: cameraX),
                ),
              ),
              Container(height: 3, color: _ink),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: _ink, size: 34),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _ink,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListenableBuilder(
                              listenable: profile,
                              builder: (context, _) => Text(
                                progress(profile),
                                style: const TextStyle(
                                  color: Palette.hazard,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
