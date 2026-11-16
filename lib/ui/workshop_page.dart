import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/tuning.dart';
import '../game/gadgets.dart';
import '../game/levels.dart';
import '../game/palette.dart';
import '../game/robot_sprites.dart';
import '../game/robot_stats.dart';
import '../game/sound.dart';
import '../profile/player_profile.dart';
import 'crt.dart';
import 'derby_route.dart';
import 'derby_button.dart';
import 'outlined_text.dart';
import 'robot_figure.dart';
import 'robot_stats_page.dart';

/// The garage: swap the robot's parts for better ones with scrap.
///
/// Left, the robot under a spotlight, wearing its installed parts (or
/// trying on the part card you tapped). Right, the five slots (legs, arms,
/// body, head, core), each with six parts from scrap (tier 0) to obsidian
/// (tier 5), and the details and Buy button for the chosen part. Parts are
/// bought in order: the next tier up in a slot is the one for sale.
class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage> {
  late final Future<RobotSprites> _sprites = RobotSprites.load();

  UpgradeTrack _slot = UpgradeTrack.values.first;

  /// The tier being looked at in the current slot (tried on in the bay).
  late int _viewTier = _nextTier(_slot);

  PlayerProfile get _profile => widget.profile;

  int _installed(UpgradeTrack track) => _profile.tierOf(track);

  /// The part worth showing first: the next one to buy, or the installed
  /// one when the slot is maxed.
  int _nextTier(UpgradeTrack track) =>
      (_installed(track) + 1).clamp(0, Tuning.upgradeMaxLevel);

  /// True while the Gadgets tab is open instead of a part slot.
  bool _gadgets = false;

  void _openGadgets() {
    Sound.play(Sfx.uiClick);
    setState(() => _gadgets = true);
  }

  void _buyGadget(Gadget gadget) {
    if (!_profile.buyGadget(gadget)) {
      return;
    }
    Sound.play(Sfx.uiBuy);
    if (_profile.hapticsOn) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _selectSlot(UpgradeTrack track) {
    Sound.play(Sfx.uiClick);
    setState(() {
      _gadgets = false;
      _slot = track;
      _viewTier = _nextTier(track);
    });
  }

  void _viewPart(int tier) {
    Sound.play(Sfx.uiClick);
    setState(() => _viewTier = tier);
  }

  void _buy() {
    if (!_profile.buyUpgrade(_slot)) {
      return;
    }
    Sound.play(Sfx.uiBuy);
    if (_profile.hapticsOn) {
      unawaited(HapticFeedback.mediumImpact());
    }
    // Show the new part installed.
    setState(() => _viewTier = _installed(_slot));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Garage.floor,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Garage.wall, _Garage.floor],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<RobotSprites>(
            future: _sprites,
            builder: (context, snapshot) => ListenableBuilder(
              listenable: _profile,
              builder: (context, _) => _layout(snapshot.data),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout(RobotSprites? sprites) {
    // The robot in the bay wears its installed parts, except the slot
    // being browsed, which shows the part you're looking at.
    int tryOn(UpgradeTrack track) =>
        !_gadgets && track == _slot ? _viewTier : _installed(track);
    return Column(
      children: [
        _Header(
          scrap: _profile.scrap,
          onBack: () => Navigator.of(context).pop(),
          onStats: () => Navigator.of(context).push(
            DerbyRoute<void>(builder: (_) => RobotStatsPage(profile: _profile)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: _RobotBay(
                    look: sprites?.look(tryOn),
                    tryingOn: _gadgets || _viewTier == _installed(_slot)
                        ? null
                        : _slot.partName(_viewTier),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SlotTabs(
                        selected: _slot,
                        installedOf: _installed,
                        onSelect: _selectSlot,
                        gadgetsSelected: _gadgets,
                        gadgetsOwned: Gadget.values
                            .where((g) => _profile.gadgetLevel(g) > 0)
                            .length,
                        onGadgets: _openGadgets,
                      ),
                      const SizedBox(height: 8),
                      if (_gadgets)
                        Expanded(
                          child: _GadgetList(
                            profile: _profile,
                            onBuy: _buyGadget,
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 124,
                          child: Row(
                            children: [
                              for (
                                var tier = 0;
                                tier <= Tuning.upgradeMaxLevel;
                                tier++
                              )
                                Expanded(
                                  child: _PartCard(
                                    sprite: sprites?.part(_slot, tier),
                                    name: _slot.partName(tier),
                                    tier: tier,
                                    installed: _installed(_slot),
                                    selected: tier == _viewTier,
                                    onTap: () => _viewPart(tier),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _PartDetails(
                            slot: _slot,
                            tier: _viewTier,
                            installed: _installed(_slot),
                            canBuy: _profile.canBuy(_slot),
                            maxTier: _profile.maxPartTier,
                            onBuy: _buy,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Garage colours: dark workshop wall and floor, a warm spotlight.
abstract final class _Garage {
  static const wall = Color(0xFF2A2E3B);
  static const floor = Color(0xFF181A22);
  static const panel = Color(0xFF242833);
  static const panelEdge = Color(0xFF3A4050);
  static const card = Color(0xFFF3E9DC);
  static const spotlight = Color(0x66FCD98A);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.scrap,
    required this.onBack,
    required this.onStats,
  });

  final int scrap;
  final VoidCallback onBack;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Palette.cream, size: 28),
          ),
          const OutlinedText('WORKSHOP', fontSize: 28, color: Palette.hazard),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              Sound.play(Sfx.uiClick);
              onStats();
            },
            icon: const Icon(Icons.bar_chart, color: Palette.hazard),
            label: const Text(
              'All stats',
              style: TextStyle(
                color: Palette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.settings, color: Palette.hazard, size: 22),
          const SizedBox(width: 6),
          OutlinedText('$scrap Scrap', fontSize: 22, color: Palette.cream),
        ],
      ),
    );
  }
}

/// The robot standing in a spotlight, with a caption when trying a part on.
class _RobotBay extends StatelessWidget {
  const _RobotBay({required this.look, required this.tryingOn});

  final RobotLook? look;

  /// Name of the part being tried on, or null when showing what's installed.
  final String? tryingOn;

  @override
  Widget build(BuildContext context) {
    final art = look;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _Garage.panelEdge, width: 2),
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.8,
          colors: [_Garage.spotlight, _Garage.panel],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The floor shadow under the robot.
                Align(
                  alignment: const Alignment(0, 0.92),
                  child: FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                if (art != null)
                  CustomPaint(
                    size: Size.infinite,
                    painter: RobotFigurePainter(
                      look: art,
                      angle: 0,
                      armSwing: 0.25,
                      metersTall: 4.3,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Pill(
              text: tryingOn == null ? 'INSTALLED' : 'TRYING ON: $tryingOn',
              color: tryingOn == null ? Crt.green : Palette.hazard,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// One tab per slot, with the installed tier under the name.
class _SlotTabs extends StatelessWidget {
  const _SlotTabs({
    required this.selected,
    required this.installedOf,
    required this.onSelect,
    required this.gadgetsSelected,
    required this.gadgetsOwned,
    required this.onGadgets,
  });

  /// The selected slot; ignored while [gadgetsSelected].
  final UpgradeTrack selected;
  final int Function(UpgradeTrack) installedOf;
  final ValueChanged<UpgradeTrack> onSelect;

  /// The Gadgets tab after the slots.
  final bool gadgetsSelected;
  final int gadgetsOwned;
  final VoidCallback onGadgets;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final track in UpgradeTrack.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _SlotTab(
                name: track.name,
                semanticLabel: '${track.name}, tier ${installedOf(track)}',
                pips: installedOf(track),
                maxPips: Tuning.upgradeMaxLevel,
                selected: !gadgetsSelected && track == selected,
                onTap: () => onSelect(track),
              ),
            ),
          ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _SlotTab(
              name: 'Gadgets',
              semanticLabel: 'Gadgets, $gadgetsOwned owned',
              pips: gadgetsOwned,
              maxPips: Gadget.values.length,
              selected: gadgetsSelected,
              onTap: onGadgets,
            ),
          ),
        ),
      ],
    );
  }
}

class _SlotTab extends StatelessWidget {
  const _SlotTab({
    required this.name,
    required this.semanticLabel,
    required this.pips,
    required this.maxPips,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String semanticLabel;

  /// Filled pips out of [maxPips] (installed tier, or gadgets owned).
  final int pips;
  final int maxPips;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Palette.outline : Palette.cream;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? Palette.hazard : _Garage.panel,
            border: Border.all(
              color: selected ? Palette.outline : _Garage.panelEdge,
              width: selected ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              _TierPips(tier: pips, max: maxPips, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pips: filled up to the installed tier.
class _TierPips extends StatelessWidget {
  const _TierPips({
    required this.tier,
    required this.color,
    this.max = Tuning.upgradeMaxLevel,
  });

  final int tier;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= max; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 3, right: 2, left: 2),
            decoration: BoxDecoration(
              color: i <= tier ? color : null,
              border: Border.all(color: color, width: 1.2),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// What a card shows about its part.
enum _CardState { owned, installed, forSale, locked }

/// A part in the current slot: its art, name and state.
class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.sprite,
    required this.name,
    required this.tier,
    required this.installed,
    required this.selected,
    required this.onTap,
  });

  final PartSprite? sprite;
  final String name;
  final int tier;
  final int installed;
  final bool selected;
  final VoidCallback onTap;

  _CardState get _state {
    if (tier < installed) {
      return _CardState.owned;
    }
    if (tier == installed) {
      return _CardState.installed;
    }
    return tier == installed + 1 ? _CardState.forSale : _CardState.locked;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final locked = state == _CardState.locked;
    final art = sprite;
    final (label, labelColor) = switch (state) {
      _CardState.owned => ('OWNED', Palette.steel),
      _CardState.installed => ('INSTALLED', const Color(0xFF2F9E5B)),
      _CardState.forSale => (
        '${Tuning.upgradePrices[tier - 1]}',
        Palette.rustShadow,
      ),
      _CardState.locked => ('LOCKED', Palette.steel),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, tier $tier, $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          decoration: BoxDecoration(
            color: _Garage.card,
            border: Border.all(
              color: selected ? Palette.hazard : Palette.outline,
              width: selected ? 4 : 2.5,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Palette.hazard.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                'T$tier',
                style: const TextStyle(
                  color: Palette.steelDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: locked ? 0.35 : 1,
                  child: art == null
                      ? const SizedBox.expand()
                      : CustomPaint(
                          size: Size.infinite,
                          painter: _PartPainter(art),
                        ),
                ),
              ),
              Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Palette.outline,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state == _CardState.forSale)
                    const Icon(
                      Icons.settings,
                      size: 11,
                      color: Palette.rustShadow,
                    ),
                  if (locked)
                    const Icon(Icons.lock, size: 11, color: Palette.steel),
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartPainter extends CustomPainter {
  _PartPainter(this.sprite);

  final PartSprite sprite;

  @override
  void paint(Canvas canvas, Size size) => sprite.renderFitted(canvas, size);

  @override
  bool shouldRepaint(_PartPainter oldDelegate) => oldDelegate.sprite != sprite;
}

/// The Gadgets tab: one row per gadget with its level, effect now and
/// next, and the Buy button (or what unlocks it).
class _GadgetList extends StatelessWidget {
  const _GadgetList({required this.profile, required this.onBuy});

  final PlayerProfile profile;
  final ValueChanged<Gadget> onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Garage.panel,
        border: Border.all(color: _Garage.panelEdge, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: Gadget.values.length,
        separatorBuilder: (_, _) =>
            const Divider(color: _Garage.panelEdge, height: 8),
        itemBuilder: (context, i) => _GadgetRow(
          gadget: Gadget.values[i],
          profile: profile,
          onBuy: () => onBuy(Gadget.values[i]),
        ),
      ),
    );
  }
}

class _GadgetRow extends StatelessWidget {
  const _GadgetRow({
    required this.gadget,
    required this.profile,
    required this.onBuy,
  });

  final Gadget gadget;
  final PlayerProfile profile;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final level = profile.gadgetLevel(gadget);
    final price = gadget.priceAfter(level);
    final unlocked = profile.isGadgetUnlocked(gadget);
    final Widget action;
    if (price == null) {
      action = const _Pill(text: 'MAXED', color: Crt.green);
    } else if (!unlocked) {
      action = SizedBox(
        width: 120,
        child: _Pill(
          text: 'UNLOCKS WITH LEVEL ${gadget.unlockLevel}',
          color: Palette.steelLight,
        ),
      );
    } else {
      action = DerbyButton(
        label: 'BUY $price',
        icon: Icons.settings,
        primary: true,
        onPressed: profile.canBuyGadget(gadget) ? onBuy : null,
        disabledNote: 'NOT ENOUGH SCRAP',
      );
    }
    final readout = price == null
        ? gadget.effect(level)
        : '${gadget.effect(level)}  →  ${gadget.effect(level + 1)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    gadget.name,
                    style: TextStyle(
                      color: unlocked ? Palette.cream : Palette.steelLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _TierPips(
                    tier: level,
                    max: Tuning.gadgetMaxLevel,
                    color: unlocked ? Palette.hazard : Palette.steelLight,
                  ),
                ],
              ),
              Text(
                gadget.description,
                style: const TextStyle(color: Palette.steelLight, fontSize: 11),
              ),
              Text(
                readout,
                style: const TextStyle(
                  color: Crt.green,
                  fontFamily: Crt.font,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    );
  }
}

/// The first level that unlocks part [tier].
int _levelFor(int tier) {
  for (var level = 1; level <= Levels.count; level++) {
    if (Levels.of(level).partTier >= tier) {
      return level;
    }
  }
  return Levels.count;
}

/// Name, what the slot does, a CRT readout of the numbers, and the action.
class _PartDetails extends StatelessWidget {
  const _PartDetails({
    required this.slot,
    required this.tier,
    required this.installed,
    required this.canBuy,
    required this.maxTier,
    required this.onBuy,
  });

  final UpgradeTrack slot;
  final int tier;
  final int installed;
  final bool canBuy;

  /// Best tier for sale (tier N opens with level N).
  final int maxTier;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final now = RobotStats.fromLevels({slot: installed}).summary(slot);
    final then = RobotStats.fromLevels({slot: tier}).summary(slot);
    final Widget action;
    if (tier == installed) {
      action = const _Pill(text: 'INSTALLED', color: Crt.green);
    } else if (tier < installed) {
      action = const _Pill(text: 'UPGRADED PAST', color: Palette.steelLight);
    } else if (tier > maxTier) {
      action = SizedBox(
        width: 140,
        child: _Pill(
          text: 'UNLOCKS WITH LEVEL ${_levelFor(tier)}',
          color: Palette.steelLight,
        ),
      );
    } else if (tier == installed + 1) {
      action = DerbyButton(
        label: 'BUY ${Tuning.upgradePrices[tier - 1]}',
        icon: Icons.settings,
        primary: true,
        onPressed: canBuy ? onBuy : null,
        disabledNote: 'NOT ENOUGH SCRAP',
      );
    } else {
      action = SizedBox(
        width: 140,
        child: _Pill(
          text: 'BUY ${slot.partName(installed + 1).toUpperCase()} FIRST',
          color: Palette.steelLight,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      decoration: BoxDecoration(
        color: _Garage.panel,
        border: Border.all(color: _Garage.panelEdge, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot.partName(tier),
                  style: const TextStyle(
                    color: Palette.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  slot.description,
                  style: const TextStyle(
                    color: Palette.steelLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Crt.background,
                    border: Border.all(color: Crt.dim, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tier == installed ? now : '$now  →  $then',
                    style: const TextStyle(
                      color: Crt.green,
                      fontFamily: Crt.font,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}
