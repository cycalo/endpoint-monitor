import 'package:dio/dio.dart';
import 'package:endpoint_monitor/feedback/feedback_form.dart';
import 'package:endpoint_monitor/feedback/formspree_feedback_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FormspreeFeedbackClient clientWith(
    void Function(RequestInterceptorHandler handler, RequestOptions options)
        onRequest,
  ) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => onRequest(handler, options),
      ),
    );
    return FormspreeFeedbackClient(dio: dio);
  }

  test('POSTs JSON to the endpoint-monitor Formspree form', () async {
    RequestOptions? captured;
    final client = clientWith((handler, options) {
      captured = options;
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: const {'ok': true},
        ),
      );
    });

    await client.submit(
      const FeedbackDraft(
        category: FeedbackCategory.idea,
        message: 'Show disk temperature.',
        email: 'dev@example.com',
      ),
    );

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.uri.toString(), kFormspreeFeedbackEndpoint);
    expect(captured!.headers['Accept'], 'application/json');
    expect(captured!.data, {
      'category': 'idea',
      'message': 'Show disk temperature.',
      '_subject': 'Endpoint Monitor feedback: Idea',
      'email': 'dev@example.com',
    });
  });

  test('does not call Formspree when the draft is invalid', () async {
    var sent = false;
    final client = clientWith((handler, options) {
      sent = true;
      handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: const {}),
      );
    });

    expect(
      () => client.submit(
        const FeedbackDraft(category: FeedbackCategory.bug, message: ''),
      ),
      throwsA(
        isA<FeedbackValidationException>().having(
          (e) => e.message,
          'message',
          kFeedbackMessageRequired,
        ),
      ),
    );
    expect(sent, isFalse);
  });

  test('maps Formspree failures to a generic error', () async {
    final client = clientWith((handler, options) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 500),
          type: DioExceptionType.badResponse,
        ),
      );
    });

    expect(
      () => client.submit(
        const FeedbackDraft(
          category: FeedbackCategory.other,
          message: 'Hello',
        ),
      ),
      throwsA(
        isA<FeedbackSubmitException>().having(
          (e) => e.message,
          'message',
          kFeedbackSubmitFailedMessage,
        ),
      ),
    );
  });

  test('maps timeouts to a generic error', () async {
    final client = clientWith((handler, options) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );
    });

    expect(
      () => client.submit(
        const FeedbackDraft(
          category: FeedbackCategory.bug,
          message: 'Timeouts on submit should stay generic.',
        ),
      ),
      throwsA(
        isA<FeedbackSubmitException>().having(
          (e) => e.message,
          'message',
          kFeedbackSubmitFailedMessage,
        ),
      ),
    );
  });
}
