import 'package:fluffy_merge/core/constants/game_constants.dart';
import 'package:fluffy_merge/core/utils/responsive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const devices = {
    'iPhone SE': Size(375, 647),
    'iPhone 15': Size(393, 793),
    'iPhone 15 Pro Max': Size(430, 873),
    'Small Android': Size(360, 640),
    'Tall Android 20:9': Size(412, 870),
    'iPad 11"': Size(834, 1150),
  };

  group('GameLayout', () {
    devices.forEach((name, size) {
      test('$name: jar keeps world aspect and fits on screen', () {
        final l = GameLayout.compute(size);
        expect(
          l.jar.width / l.jar.height,
          closeTo(GameConstants.jarAspect, 1e-6),
        );
        expect(l.jar.left, greaterThanOrEqualTo(0));
        expect(l.jar.right, lessThanOrEqualTo(size.width));
        expect(l.jar.top, greaterThanOrEqualTo(l.hud.bottom));
        expect(l.jar.bottom, lessThanOrEqualTo(l.powerBar.top));
        // Jar should be the dominant element (~60–75% of height on phones).
        if (size.shortestSide < 600) {
          expect(l.jar.height / size.height, greaterThan(0.55));
        }
      });
    });
  });

  test('device classes', () {
    expect(Responsive.of(const Size(360, 640)).isCompact, isTrue);
    expect(Responsive.of(const Size(393, 793)).deviceClass, DeviceClass.phone);
    expect(Responsive.of(const Size(834, 1150)).isTablet, isTrue);
  });
}
