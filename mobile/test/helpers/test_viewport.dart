import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the test surface to a phone-portrait width so a screen test keeps
/// exercising RESP-1's <600dp single-pane layout regardless of the default
/// 800x600 test viewport — which is itself ≥600dp wide, i.e. "tablet" by
/// RESP-1's own breakpoint. Slice 7 added the ≥600dp two-pane layout to the
/// vehicles/alerts branches; without pinning, every prior single-pane
/// widget test would silently start exercising the wide layout instead of
/// the one its name/assertions describe.
void pinPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
