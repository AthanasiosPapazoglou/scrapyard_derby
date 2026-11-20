import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../game/races.dart';
import '../game/sound.dart';
import '../profile/player_profile.dart';
import 'layout.dart';
import 'page_header.dart';
import 'still_scene.dart';

/// Versus mode (Play → Versus): the six races as cards, each on a level's
/// hill, with its race gear, the 3 rivals and the best place. A race opens
/// by winning the one before it.
class VersusLadderPage extends StatelessWidget {
  const VersusLadderPage({super.key, required this.profile});

  final PlayerProfile profile;

  void _race(BuildContext context, int race) {
    Sound.play(Sfx.uiClick);
    // Racing itself arrives with roadmap step R2. Until then a race card
    // only says so (a plain run here would record a Survival best with
    // the race gear).
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Race $race: racing arrives in the next build.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: StillScene(LevelTheme.of(1))),
          SafeArea(
            child: ListenableBuilder(
              listenable: profile,
              builder: (context, _) => Column(
                children: [
                  PageHeader(
                    title: 'VERSUS',
                    onBack: () => Navigator.of(context).pop(),
                    trailing: [
                      HeaderCount(
                        icon: Icons.emoji_events,
                        text: '${profile.racesWon} / ${Races.count}',
                      ),
                      HeaderCount(
                        icon: Icons.settings,
                        text: '${profile.scrap}',
                        label: 'Scrap',
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      // 3 × 2 cards in landscape, 2 × 3 in portrait.
                      child: Builder(
                        builder: (context) {
                          final columns = context.isPortrait ? 2 : 3;
                          final rows = (Races.count / columns).ceil();
                          return Column(
                            children: [
                              for (var row = 0; row < rows; row++)
                                Expanded(
                                  child: Row(
                                    children: [
                                      for (var col = 1; col <= columns; col++)
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(5),
                                            child: _RaceCard(
                                              race: row * columns + col,
                                              profile: profile,
                                              onRace: (race) =>
                                                  _race(context, race),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One race: number, hill, best place, race gear and rivals, or a lock.
/// The furthest open race is highlighted in hazard yellow.
class _RaceCard extends StatelessWidget {
  const _RaceCard({
    required this.race,
    required this.profile,
    required this.onRace,
  });

  final int race;
  final PlayerProfile profile;
  final void Function(int race) onRace;

  static const _ink = Palette.outline;

  @override
  Widget build(BuildContext context) {
    final tuning = Races.of(race);
    final hill = Races.levelOf(race);
    final unlocked = profile.isRaceUnlocked(race);
    final best = profile.bestPlaceOn(race);
    final current = race == profile.highestUnlockedRace;
    final fill = !unlocked
        ? Palette.steel
        : (current ? Palette.hazard : Palette.cream);
    final textColor = unlocked ? _ink : Palette.steelLight;
    final gadgets = tuning.gadgets.isEmpty ? '' : ' + gadgets';

    final String status;
    if (!unlocked) {
      status = 'Win race ${race - 1}';
    } else if (best == null) {
      status = 'Not raced';
    } else {
      status = 'Best: ${Races.placeLabel(best)}';
    }

    return Semantics(
      button: unlocked,
      label:
          'Race $race, ${hill.name}, '
          '${!unlocked
              ? 'locked'
              : best == null
              ? 'not raced'
              : 'best ${Races.placeLabel(best)}'}',
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _ink, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unlocked ? () => onRace(race) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A window onto the hill's scenery (grey while locked).
              Expanded(
                flex: 2,
                child: ColorFiltered(
                  colorFilter: unlocked ? noFilter : greyscaleFilter,
                  child: CustomPaint(
                    painter: StillScene(
                      LevelTheme.of(tuning.level),
                      cameraX: race * 53.0,
                    ),
                  ),
                ),
              ),
              Container(height: 3, color: _ink),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$race',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hill.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (!unlocked) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.lock,
                                  size: 18,
                                  color: Palette.steelLight,
                                ),
                              ],
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                best == 1
                                    ? Icons.emoji_events
                                    : Icons.emoji_events_outlined,
                                size: 24,
                                color: textColor,
                              ),
                              const SizedBox(width: 4),
                              Text(status),
                            ],
                          ),
                          Text('Tier ${tuning.partTier} gear$gadgets'),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final rival in tuning.rivals) ...[
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: unlocked
                                        ? Color(rival.color)
                                        : Palette.steelLight,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _ink),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rival.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
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
