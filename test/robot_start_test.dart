import 'package:flutter_test/flutter_test.dart';
import 'package:scrapyard_derby/config/tuning.dart';
import 'package:scrapyard_derby/game/hill.dart';
import 'package:scrapyard_derby/game/robot.dart';

void main() {
  test('the robot is dropped from high above the slope', () {
    final hill = HillGeometry();
    // Constructing a Robot only computes its start; no physics runs here.
    final robot = Robot(hill: hill);
    final groundBelow = hill.heightAt(robot.start.x);
    // y points down, so height above ground = ground y - torso y.
    final torsoHeight = groundBelow - robot.start.y;
    // Torso sits ~1.6 m above the feet; the feet start startDropHeight up
    // along the slope's normal, which is a bit more than that vertically.
    expect(torsoHeight, greaterThan(Tuning.startDropHeight));
  });
}
