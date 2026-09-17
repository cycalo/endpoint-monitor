import 'package:dio/dio.dart';

import 'feedback_form.dart';

/// Public Formspree form for the ENDPOINT-MONITOR project only.
const String kFormspreeFeedbackEndpoint = 'https://formspree.io/f/mppwzyeo';

class FormspreeFeedbackClient {
  FormspreeFeedbackClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<void> submit(FeedbackDraft draft) async {
    final error = validateFeedbackDraft(draft);
    if (error != null) {
      throw FeedbackValidationException(error);
    }

    try {
      final response = await _dio.post<dynamic>(
        kFormspreeFeedbackEndpoint,
        data: formspreeFeedbackPayload(draft),
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw const FeedbackSubmitException(kFeedbackSubmitFailedMessage);
      }
    } on FeedbackValidationException {
      rethrow;
    } on FeedbackSubmitException {
      rethrow;
    } on DioException {
      throw const FeedbackSubmitException(kFeedbackSubmitFailedMessage);
    } catch (_) {
      throw const FeedbackSubmitException(kFeedbackSubmitFailedMessage);
    }
  }
}
