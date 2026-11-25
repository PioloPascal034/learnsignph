import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnsignph/screens/live_practice_screen.dart';

void main() {
  const camera = CameraDescription(
    name: 'test',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 90,
  );

  test('uses the same orientation as CameraPreview', () {
    final value = const CameraValue.uninitialized(camera).copyWith(
      previewSize: const Size(640, 480),
      deviceOrientation: DeviceOrientation.portraitUp,
    );
    expect(LiveCameraViewport.aspectRatioFor(value), 3 / 4);
    expect(
        LiveCameraViewport.aspectRatioFor(value.copyWith(
          deviceOrientation: DeviceOrientation.landscapeLeft,
        )),
        4 / 3);
  });

  for (final size in [
    const Size(360, 640),
    const Size(450, 940),
    const Size(800, 450)
  ]) {
    testWidgets('preserves full portrait preview at $size without a height cap',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const previewKey = ValueKey('camera-image');
      const overlayKey = ValueKey('landmark-overlay');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: LiveCameraViewport(
              aspectRatio: 3 / 4,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(key: previewKey, color: Colors.black),
                SizedBox.expand(key: overlayKey),
              ]),
            ),
          ),
          Text('Recognition result'),
        ])),
      ));
      final imageSize = tester.getSize(find.byKey(previewKey));
      expect(imageSize.height, closeTo((size.width - 36) * 4 / 3, 0.01));
      expect(tester.getSize(find.byKey(overlayKey)), imageSize);
      expect(tester.takeException(), isNull);
    });
  }
}
