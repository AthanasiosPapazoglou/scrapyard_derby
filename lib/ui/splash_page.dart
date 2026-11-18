import 'package:flutter/material.dart';
import 'package:thanos_productions/thanos_productions.dart';

import '../game/sound.dart';
import 'derby_route.dart';

/// The first page on every launch: the Thanos Productions creator splash
/// (see the thanos_productions package). Its ding plays at the
/// sound-effects volume; when it ends (or is tapped away) the music starts
/// and [next] fades in.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.next});

  final WidgetBuilder next;

  @override
  Widget build(BuildContext context) {
    return ThanosSplash(
      onDing: Sound.playBrandDing,
      onDone: () {
        Sound.startMusic();
        Navigator.of(context).pushReplacement(DerbyRoute<void>(builder: next));
      },
    );
  }
}
