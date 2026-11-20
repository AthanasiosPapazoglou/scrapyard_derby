import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../game/races.dart';
import '../game/robot_sprites.dart';
import '../game/sound.dart';
import '../profile/page_tour.dart';
import '../profile/player_profile.dart';
import 'derby_route.dart';
import 'game_page.dart';
import 'layout.dart';
import 'page_header.dart';
import 'robot_figure.dart';
import 'spotlight_tour.dart';
import 'still_scene.dart';

/// Versus mode (Play → Versus): the six races as cards, each on a level's
/// hill, with the robot in its race gear, the 3 rivals and the best place
/// (a medal). A race opens by winning the one before it. A first-visit
/// tour explains race gear, rivals and unlocking (D53).
class VersusLadderPage extends StatefulWidget {
  const VersusLadderPage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<VersusLadderPage> createState() => _VersusLadderPageState();
}

class _VersusLadderPageState extends State<VersusLadderPage> {
  PlayerProfile get profile => widget.profile;

  /// Part art for the robots on the cards (loaded once, cached).
  late final Future<RobotSprites> _sprites = RobotSprites.load();

  // First-visit tour targets.
  final _firstRaceKey = GlobalKey();
  final _rivalsKey = GlobalKey();
  final _secondRaceKey = GlobalKey();

  void _race(BuildContext context, int race) {
    Sound.play(Sfx.uiClick);
    Navigator.of(context).push(
      DerbyRoute<void>(
        builder: (_) => GamePage(profile: profile, race: race),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.skyTop,
      body: SpotlightTour(
        tour: PageTour.ladder,
        profile: profile,
        steps: [
          TourStep(
            target: _firstRaceKey,
            title: 'RACE GEAR',
            text:
                'Every race hands you its own robot. Workshop upgrades and '
                'gadgets only count in Survival.',
          ),
          TourStep(
            target: _rivalsKey,
            title: 'RIVALS',
            text:
                '3 rivals race the same hill with the same gear. They '
                'never touch you.',
          ),
          TourStep(
            target: _secondRaceKey,
            title: 'WIN TO UNLOCK',
            text:
                'Finish 1st to open the next race. Every race pays scrap '
                'for your Survival robot.',
          ),
        ],
        child: Stack(
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
                                                key: switch (row * columns +
                                                    col) {
                                                  1 => _firstRaceKey,
                                                  2 => _secondRaceKey,
                                                  _ => null,
                                                },
                                                rivalsKey:
                                                    row * columns + col == 1
                                                    ? _rivalsKey
                                                    : null,
                                                race: row * columns + col,
                                                profile: profile,
                                                sprites: _sprites,
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
      ),
    );
  }
}

/// One race: number, hill, best place, race gear and rivals, or a lock.
/// The furthest open race is highlighted in hazard yellow.
class _RaceCard extends StatelessWidget {
  const _RaceCard({
    super.key,
    this.rivalsKey,
    required this.race,
    required this.profile,
    required this.sprites,
    required this.onRace,
  });

  final int race;
  final PlayerProfile profile;
  final Future<RobotSprites> sprites;
  final void Function(int race) onRace;

  /// Tour target on the rivals row (race 1 only).
  final GlobalKey? rivalsKey;

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
                    // The robot in this race's gear, mid-hop on the hill.
                    child: FutureBuilder<RobotSprites>(
                      future: sprites,
                      builder: (context, loaded) => switch (loaded.data) {
                        final art? => Align(
                          alignment: const Alignment(0.75, 0.2),
                          child: FractionallySizedBox(
                            heightFactor: 0.9,
                            child: AspectRatio(
                              aspectRatio: 0.8,
                              child: CustomPaint(
                                painter: RobotFigurePainter(
                                  look: art.look(
                                    (track) => Races.tierOf(race, track),
                                  ),
                                  angle: 0.18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        null => const SizedBox.shrink(),
                      },
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
                              _Medal(place: best, color: textColor),
                              const SizedBox(width: 4),
                              Text(status),
                            ],
                          ),
                          Text('Tier ${tuning.partTier} gear$gadgets'),
                          const SizedBox(height: 2),
                          Row(
                            key: rivalsKey,
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

/// The best place as a medal: gold, silver, bronze, or an empty trophy
/// outline (4th or never raced).
class _Medal extends StatelessWidget {
  const _Medal({required this.place, required this.color});

  final int? place;

  /// Outline colour (ink, or grey while locked).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final metal = switch (place) {
      1 => Palette.hazard,
      2 => Palette.steelLight,
      3 => Palette.rustLight,
      _ => null,
    };
    if (metal == null) {
      return Icon(Icons.emoji_events_outlined, size: 24, color: color);
    }
    return Icon(
      Icons.military_tech,
      size: 26,
      color: metal,
      shadows: const [Shadow(color: Palette.outline, blurRadius: 2)],
    );
  }
}
