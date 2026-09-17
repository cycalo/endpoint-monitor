import 'package:endpoint_monitor/bloc/connection_bloc.dart';
import 'package:endpoint_monitor/feedback/feedback_form.dart';
import 'package:endpoint_monitor/screens/feedback_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<void> Function(FeedbackDraft draft)? onSubmit,
  }) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final bloc = ConnectionBloc(const FlutterSecureStorage());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          home: FeedbackScreen(submitFeedback: onSubmit),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows category, message, and optional email fields',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Idea'), findsOneWidget);
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.byKey(const Key('feedback-message')), findsOneWidget);
    expect(find.byKey(const Key('feedback-email')), findsOneWidget);
  });

  testWidgets('does not submit an empty message', (tester) async {
    FeedbackDraft? submitted;
    await pumpScreen(tester, onSubmit: (draft) async {
      submitted = draft;
    });

    await tester.ensureVisible(find.text('SEND FEEDBACK'));
    await tester.tap(find.text('SEND FEEDBACK'));
    await tester.pump();

    expect(find.text(kFeedbackMessageRequired), findsOneWidget);
    expect(submitted, isNull);
  });

  testWidgets('submits idea/bug/other with optional email', (tester) async {
    FeedbackDraft? submitted;
    await pumpScreen(tester, onSubmit: (draft) async {
      submitted = draft;
    });

    await tester.tap(find.text('Bug'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('feedback-message')),
      'Network list is empty.',
    );
    await tester.enterText(
      find.byKey(const Key('feedback-email')),
      'pat@example.com',
    );
    await tester.ensureVisible(find.text('SEND FEEDBACK'));
    await tester.tap(find.text('SEND FEEDBACK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(submitted, isNotNull);
    expect(submitted!.category, FeedbackCategory.bug);
    expect(submitted!.message, 'Network list is empty.');
    expect(submitted!.email, 'pat@example.com');
    expect(find.textContaining('Thanks'), findsOneWidget);
  });
}
