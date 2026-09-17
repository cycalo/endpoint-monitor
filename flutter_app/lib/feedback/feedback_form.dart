enum FeedbackCategory { idea, bug, other }

extension FeedbackCategoryLabel on FeedbackCategory {
  String get label => switch (this) {
        FeedbackCategory.idea => 'Idea',
        FeedbackCategory.bug => 'Bug',
        FeedbackCategory.other => 'Other',
      };
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.category,
    required this.message,
    this.email = '',
  });

  final FeedbackCategory category;
  final String message;
  final String email;
}

const int kFeedbackMessageMaxLength = 4000;
const int kFeedbackEmailMaxLength = 254;

const String kFeedbackMessageRequired = 'Enter a message.';
const String kFeedbackMessageTooLong =
    'Keep your message under 4000 characters.';
const String kFeedbackEmailInvalid = 'Enter a valid email or leave it blank.';
const String kFeedbackSubmitFailedMessage =
    'Could not send feedback. Try again later.';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateFeedbackDraft(FeedbackDraft draft) {
  final message = draft.message.trim();
  if (message.isEmpty) return kFeedbackMessageRequired;
  if (message.length > kFeedbackMessageMaxLength) {
    return kFeedbackMessageTooLong;
  }

  final email = draft.email.trim();
  if (email.isEmpty) return null;
  if (email.length > kFeedbackEmailMaxLength ||
      !_emailPattern.hasMatch(email)) {
    return kFeedbackEmailInvalid;
  }
  return null;
}

Map<String, String> formspreeFeedbackPayload(FeedbackDraft draft) {
  final payload = <String, String>{
    'category': draft.category.name,
    'message': draft.message.trim(),
    '_subject': 'Endpoint Monitor feedback: ${draft.category.label}',
  };
  final email = draft.email.trim();
  if (email.isNotEmpty) payload['email'] = email;
  return payload;
}

class FeedbackValidationException implements Exception {
  const FeedbackValidationException(this.message);
  final String message;
}

class FeedbackSubmitException implements Exception {
  const FeedbackSubmitException(this.message);
  final String message;
}
