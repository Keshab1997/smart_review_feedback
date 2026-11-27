import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_review_feedback/smart_review_feedback.dart';

FeedbackReport _sampleReport() {
  return FeedbackReport(
    rating: 2,
    categories: const <String>['Bug / Crash'],
    message: 'Crash when tapping export',
    contact: 'user@example.com',
    diagnostics: ReviewDiagnostics(
      appName: 'Khoroch Diary',
      appVersion: '1.3.0',
      buildNumber: '13',
      platform: 'android',
      submittedAtUtc: DateTime.utc(2026, 11, 27, 12, 0),
      screenName: 'BackupScreen',
    ),
  );
}

void main() {
  group('FeedbackSink implementations', () {
    test('WebhookFeedbackSink posts JSON report', () async {
      Map<String, dynamic>? received;
      final client = MockClient((http.Request req) async {
        expect(req.method, 'POST');
        expect(req.url.toString(), 'https://hooks.example.com/feedback');
        received = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      });

      final sink = WebhookFeedbackSink(
        'https://hooks.example.com/feedback',
        client: client,
      );
      await sink.send(_sampleReport());
      expect(received?['rating'], 2);
      expect(received?['message'], 'Crash when tapping export');
    });

    test('TelegramFeedbackSink sends formatted text to sendMessage', () async {
      Map<String, dynamic>? payload;
      final client = MockClient((http.Request req) async {
        expect(
          req.url.toString(),
          'https://api.telegram.org/botTEST_TOKEN/sendMessage',
        );
        payload = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      });

      final sink = TelegramFeedbackSink(
        botToken: 'TEST_TOKEN',
        chatId: '12345',
        client: client,
      );
      await sink.send(_sampleReport());
      expect(payload?['chat_id'], '12345');
      expect(payload?['text'], contains('Khoroch Diary'));
      expect(payload?['text'], contains('Crash when tapping export'));
    });

    test('MultiFeedbackSink succeeds if one sink succeeds when requireAll=false',
        () async {
      final good = MemoryFeedbackSink();
      final bad = MemoryFeedbackSink(
        errorToThrow: const FeedbackDeliveryException('Offline'),
      );
      final multi = MultiFeedbackSink(<FeedbackSink>[bad, good]);

      await multi.send(_sampleReport());
      expect(good.reports, hasLength(1));
    });
  });
}
