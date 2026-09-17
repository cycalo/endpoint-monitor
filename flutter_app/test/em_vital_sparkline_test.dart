import 'package:endpoint_monitor/widgets/system_monitor/em_vital_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emVitalSparklinePath', () {
    test('returns empty path for no values', () {
      final path = emVitalSparklinePath(
        values: [],
        size: const Size(100, 50),
      );
      expect(path.getBounds().isEmpty, isTrue);
    });

    test('single point returns without error', () {
      expect(
        () => emVitalSparklinePath(
          values: [50],
          size: const Size(100, 50),
        ),
        returnsNormally,
      );
    });

    test('monotonic x increases left to right', () {
      final path = emVitalSparklinePath(
        values: [10, 30, 50, 70],
        size: const Size(100, 50),
      );
      final bounds = path.getBounds();
      expect(bounds.left, lessThan(bounds.right));
    });

    test('higher values draw higher on the chart (smaller y)', () {
      final low = emVitalSparklinePath(
        values: [10, 20],
        size: const Size(100, 50),
      );
      final high = emVitalSparklinePath(
        values: [80, 90],
        size: const Size(100, 50),
      );
      expect(high.getBounds().bottom, lessThan(low.getBounds().bottom));
    });
  });

  testWidgets('EmVitalSparkline renders without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmVitalSparkline(
            values: [10, 20, 15, 30],
            color: Colors.cyan,
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(EmVitalSparkline),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
