import 'package:endpoint_monitor/feedback/feedback_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateFeedbackDraft', () {
    test('requires a non-empty message', () {
      expect(
        validateFeedbackDraft(
          const FeedbackDraft(category: FeedbackCategory.idea, message: ''),
        ),
        kFeedbackMessageRequired,
      );
      expect(
        validateFeedbackDraft(
          const FeedbackDraft(category: FeedbackCategory.bug, message: '   '),
        ),
        kFeedbackMessageRequired,
      );
    });

    test('rejects a message over the max length', () {
      final message = 'x' * (kFeedbackMessageMaxLength + 1);
      expect(
        validateFeedbackDraft(
          FeedbackDraft(category: FeedbackCategory.other, message: message),
        ),
        kFeedbackMessageTooLong,
      );
    });

    test('allows a missing email', () {
      expect(
        validateFeedbackDraft(
          const FeedbackDraft(
            category: FeedbackCategory.idea,
            message: 'Ship dark mode for the events chart.',
          ),
        ),
        isNull,
      );
    });

    test('rejects an invalid email when one is provided', () {
      expect(
        validateFeedbackDraft(
          const FeedbackDraft(
            category: FeedbackCategory.bug,
            message: 'Alerts never clear.',
            email: 'not-an-email',
          ),
        ),
        kFeedbackEmailInvalid,
      );
    });

    test('accepts a valid email with a message', () {
      expect(
        validateFeedbackDraft(
          const FeedbackDraft(
            category: FeedbackCategory.other,
            message: 'Love the firewall screen.',
            email: 'user@example.com',
          ),
        ),
        isNull,
      );
    });
  });

  group('formspreeFeedbackPayload', () {
    test('sends category, trimmed message, and a subject', () {
      final payload = formspreeFeedbackPayload(
        const FeedbackDraft(
          category: FeedbackCategory.bug,
          message: '  CPU graph freezes  ',
        ),
      );

      expect(payload['category'], 'bug');
      expect(payload['message'], 'CPU graph freezes');
      expect(payload['_subject'], 'Endpoint Monitor feedback: Bug');
      expect(payload.containsKey('email'), isFalse);
    });

    test('includes email only when provided', () {
      final withEmail = formspreeFeedbackPayload(
        const FeedbackDraft(
          category: FeedbackCategory.idea,
          message: 'Add a sleep timer.',
          email: '  alex@example.com  ',
        ),
      );
      expect(withEmail['email'], 'alex@example.com');

      final blankEmail = formspreeFeedbackPayload(
        const FeedbackDraft(
          category: FeedbackCategory.idea,
          message: 'Add a sleep timer.',
          email: '   ',
        ),
      );
      expect(blankEmail.containsKey('email'), isFalse);
    });
  });
}
