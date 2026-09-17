import 'package:endpoint_monitor/connect/connect_path.dart';
import 'package:endpoint_monitor/screens/connect_guided_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wifi guided page shows wifi title and pairing code field', (tester) async {
    final address = TextEditingController();
    final code = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConnectGuidedPage(
              path: ConnectPath.wifi,
              alreadyPaired: false,
              addressController: address,
              codeController: code,
              rememberAddress: true,
              busy: false,
              connecting: false,
              errorMessage: null,
              onRememberChanged: (_) {},
              onBack: () {},
              onConnect: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Connect over Wi-Fi'), findsOneWidget);
    expect(find.text('6-DIGIT CODE'), findsOneWidget);
    expect(find.textContaining('Tailscale'), findsNothing);
  });

  testWidgets('tailscale guided page shows tailscale title and install copy', (tester) async {
    final address = TextEditingController();
    final code = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConnectGuidedPage(
              path: ConnectPath.tailscale,
              alreadyPaired: false,
              addressController: address,
              codeController: code,
              rememberAddress: true,
              busy: false,
              connecting: false,
              errorMessage: null,
              onRememberChanged: (_) {},
              onBack: () {},
              onConnect: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Connect with Tailscale'), findsOneWidget);
    expect(find.text('install Tailscale'), findsNWidgets(2));
    expect(find.text('6-DIGIT CODE'), findsOneWidget);
  });

  testWidgets('hides pairing code when already paired', (tester) async {
    final address = TextEditingController();
    final code = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConnectGuidedPage(
              path: ConnectPath.wifi,
              alreadyPaired: true,
              addressController: address,
              codeController: code,
              rememberAddress: true,
              busy: false,
              connecting: false,
              errorMessage: null,
              onRememberChanged: (_) {},
              onBack: () {},
              onConnect: () {},
              onPairAgain: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('6-DIGIT CODE'), findsNothing);
    expect(find.textContaining('already paired'), findsOneWidget);
    expect(find.text('Use a new pairing code'), findsOneWidget);
  });
}
