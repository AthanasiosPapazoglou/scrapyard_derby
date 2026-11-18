// Renders the app icon SVGs (art/icon/, from art/make_icon.py) into every
// PNG the platforms need: iOS AppIcon set, Android launcher icons
// (classic + adaptive layers), web icons and favicon. Not part of the
// normal test run; after changing the icon:
//
//   python3 art/make_icon.py
//   flutter test tool/render_icons_test.dart
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android densities: folder suffix and scale (mdpi = 1).
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render app icons', () async {
    await _render();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _render() async {
  final full = await _load('art/icon/icon.svg');
  final background = await _load('art/icon/adaptive_background.svg');
  final foreground = await _load('art/icon/adaptive_foreground.svg');
  final maskable = await _load('art/icon/icon_maskable.svg');

  // iOS: every image in the AppIcon set, opaque (no alpha channel; App
  // Store Connect rejects icons with one).
  const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final contents =
      jsonDecode(File('$ios/Contents.json').readAsStringSync())
          as Map<String, dynamic>;
  final done = <String>{};
  for (final image in contents['images'] as List<dynamic>) {
    final map = image as Map<String, dynamic>;
    final name = map['filename'] as String?;
    if (name == null || !done.add(name)) {
      continue;
    }
    final points = double.parse((map['size'] as String).split('x').first);
    final scale = double.parse((map['scale'] as String).replaceAll('x', ''));
    final px = (points * scale).round();
    await _write('$ios/$name', await _png(full, px, opaque: true));
  }

  // Android: classic icons (rounded square) and adaptive icon layers.
  const res = 'android/app/src/main/res';
  for (final MapEntry(key: dpi, value: scale) in _densities.entries) {
    await _write(
      '$res/mipmap-$dpi/ic_launcher.png',
      await _png(full, (48 * scale).round(), corner: 0.18),
    );
    final layer = (108 * scale).round();
    await _write(
      '$res/mipmap-$dpi/ic_launcher_background.png',
      await _png(background, layer, opaque: true),
    );
    await _write(
      '$res/mipmap-$dpi/ic_launcher_foreground.png',
      await _png(foreground, layer),
    );
  }

  // Web: favicon, app icons, and maskable icons (full bleed, the content
  // inside the safe circle).
  await _write('web/favicon.png', await _png(full, 64, corner: 0.18));
  for (final px in [192, 512]) {
    await _write(
      'web/icons/Icon-$px.png',
      await _png(full, px, corner: 0.18),
    );
    await _write(
      'web/icons/Icon-maskable-$px.png',
      await _png(maskable, px, opaque: true),
    );
  }
}

Future<PictureInfo> _load(String path) =>
    vg.loadPicture(SvgStringLoader(File(path).readAsStringSync()), null);

/// [svg] as a [px]-square PNG. [corner] rounds the corners (share of the
/// size; transparent outside). [opaque] writes RGB without alpha.
Future<Uint8List> _png(
  PictureInfo svg,
  int px, {
  double corner = 0,
  bool opaque = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final scale = px / svg.size.width;
  if (corner > 0) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
        Radius.circular(px * corner),
      ),
    );
  }
  canvas
    ..scale(scale)
    ..drawPicture(svg.picture);
  final image = await recorder.endRecording().toImage(px, px);
  if (!opaque) {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _encodeRgbPng(px, px, rgba!.buffer.asUint8List());
}

Future<void> _write(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  print('wrote $path (${bytes.length} bytes)');
}

/// A minimal PNG encoder for 8-bit RGB (colour type 2, no alpha).
Uint8List _encodeRgbPng(int width, int height, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw
        ..addByte(rgba[i])
        ..addByte(rgba[i + 1])
        ..addByte(rgba[i + 2]);
    }
  }
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc32(body)));
  }

  chunk('IHDR', [..._u32(width), ..._u32(height), 8, 2, 0, 0, 0]);
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
