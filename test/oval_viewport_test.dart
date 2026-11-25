import 'dart:ui';

import 'package:vnpt_kyc_plugin/src/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('far and near guides match the SDK on a tall iPhone', () {
    const screen = Size(428, 926);
    final viewport = ovalViewport(screen);
    final far = projectOvalGuide(
      normalizedOvalOverlay(isFar: true, useIosGuide: true),
      viewport,
    );
    final near = projectOvalGuide(
      normalizedOvalOverlay(isFar: false, useIosGuide: true),
      viewport,
    );

    // The 3:4 camera viewport has the same center as the screen.
    expect(
        viewport,
        rectMoreOrLessEquals(
          const Rect.fromLTWH(0, 533 / 3, 428, 1712 / 3),
        ));
    expect(far.center, offsetMoreOrLessEquals(const Offset(214, 463)));
    expect(near.center, offsetMoreOrLessEquals(const Offset(214, 463)));
    expect(far.width, closeTo(214, 0.01));
    expect(far.height, closeTo(321, 0.01));
    expect(near.width, closeTo(321, 0.01));
    expect(near.height, closeTo(561.75, 0.01));
    expect(near.top, greaterThan(180));
    expect(near.bottom, lessThan(746));
  });

  test('guide and camera viewport fit when height limits the layout', () {
    const screen = Size(926, 428);
    final viewport = ovalViewport(screen);
    final near =
        projectOvalGuide(normalizedOvalOverlay(isFar: false), viewport);

    expect(viewport, const Rect.fromLTWH(302.5, 0, 321, 428));
    expect(near.center, offsetMoreOrLessEquals(screen.center(Offset.zero)));
    expect(near.left, greaterThan(viewport.left));
    expect(near.right, lessThan(viewport.right));
    expect(near.top, greaterThan(viewport.top));
    expect(near.bottom, lessThan(viewport.bottom));
  });

  test('oval trên màn hình trùng viewport cũ khi preview và màn cùng 3:4', () {
    const size = Size(480, 640);
    final normalized = normalizedOvalOverlay(isFar: true);
    final onScreen = ovalGuideOnScreen(
        normalized: normalized, preview: size, screen: size);
    final old = projectOvalGuide(normalized, ovalViewport(size));
    expect(onScreen.left, closeTo(old.left, 0.01));
    expect(onScreen.right, closeTo(old.right, 0.01));
    expect(onScreen.top, closeTo(old.top, 0.01));
    expect(onScreen.bottom, closeTo(old.bottom, 0.01));
  });

  test('màn cao: oval far vẫn nằm giữa màn hình', () {
    final rect = ovalGuideOnScreen(
      normalized: normalizedOvalOverlay(isFar: true),
      preview: const Size(1080, 1920),
      screen: const Size(430, 820),
    );
    expect(rect.center.dx, closeTo(215, 0.01));
    expect(rect.center.dy, closeTo(410, 0.01));
  });
}
