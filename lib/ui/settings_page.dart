import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../game/sound.dart';
import '../profile/player_profile.dart';
import 'derby_button.dart';
import 'outlined_text.dart';

/// Volumes, vibration, debug info, reset progress and credits. Every change
/// goes straight into the [PlayerProfile], which saves itself.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.skyTop,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: profile,
          builder: (context, _) => Column(
            children: [
              _Header(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _Panel(
                              title: 'SOUND',
                              children: [
                                _VolumeRow(
                                  label: 'Music',
                                  icon: Icons.music_note,
                                  value: profile.musicVolume,
                                  onChanged: (v) => profile.musicVolume = v,
                                ),
                                _VolumeRow(
                                  label: 'Sound effects',
                                  icon: Icons.volume_up,
                                  value: profile.sfxVolume,
                                  onChanged: (v) => profile.sfxVolume = v,
                                  // A sample at the new volume.
                                  onChangeEnd: (_) => Sound.play(Sfx.landClean),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Panel(
                              title: 'GAME',
                              children: [
                                _SwitchRow(
                                  label: 'Vibration',
                                  icon: Icons.vibration,
                                  value: profile.hapticsOn,
                                  onChanged: (v) => profile.hapticsOn = v,
                                ),
                                _SwitchRow(
                                  label: 'Show debug info',
                                  icon: Icons.bug_report,
                                  value: profile.showDebugInfo,
                                  onChanged: (v) => profile.showDebugInfo = v,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _Panel(
                              title: 'PROGRESS',
                              children: [
                                Text(
                                  '${profile.totalStars} stars'
                                  '  ·  Best ${profile.bestDistance.toStringAsFixed(0)} m'
                                  '  ·  ${profile.scrap} Scrap',
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: DerbyButton(
                                    label: 'Reset progress',
                                    icon: Icons.delete_forever,
                                    onPressed: () =>
                                        confirmResetProgress(context, profile),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const _Credits(),
                          ],
                        ),
                      ),
                    ],
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

/// Asks first, then wipes best distance, scrap and upgrades (settings
/// stay). Returns true if the player confirmed.
Future<bool> confirmResetProgress(
  BuildContext context,
  PlayerProfile profile,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Palette.hazard,
      title: const Text('Reset progress?'),
      content: Text(
        'This wipes your best distances and ${profile.totalStars} stars '
        '(levels lock again), ${profile.scrap} Scrap and all upgrades. '
        'Settings are kept.\n\n'
        "This can't be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Palette.outline),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.rustShadow,
            foregroundColor: Palette.cream,
          ),
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    profile.resetProgress();
    return true;
  }
  return false;
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Palette.cream, size: 30),
          ),
          const SizedBox(width: 8),
          const OutlinedText('SETTINGS', fontSize: 32, color: Palette.hazard),
        ],
      ),
    );
  }
}

/// A cream card with a small title, in the cutout style.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Palette.cream,
        border: Border.all(color: Palette.outline, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Palette.outline,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Palette.rustShadow,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Palette.outline),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            label: label,
            activeColor: Palette.rust,
            inactiveColor: Palette.steelLight,
            thumbColor: Palette.hazard,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('${(value * 100).round()}%', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Palette.outline),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.hazard,
          activeTrackColor: Palette.rust,
        ),
      ],
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'CREDITS',
      children: [
        const Text('Scrapyard Derby (working title)'),
        const Text(
          'A hobby game. All art, sound and code are original.\n'
          'Built with Flutter, Flame and Forge2D (Box2D).',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Scrapyard Derby',
          ),
          style: TextButton.styleFrom(
            foregroundColor: Palette.rustShadow,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Open-source licenses'),
        ),
      ],
    );
  }
}
