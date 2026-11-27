import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/feedback_report.dart';

/// Exception raised when a [FeedbackSink] fails to deliver a [FeedbackReport].
class FeedbackDeliveryException implements Exception {
  const FeedbackDeliveryException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final code = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'FeedbackDeliveryException$code: $message';
  }
}

/// Destination for 1–3 star user improvement feedback.
abstract class FeedbackSink {
  const FeedbackSink();

  /// Delivers [report]. Throw [FeedbackDeliveryException] on failure.
  Future<void> send(FeedbackReport report);
}

/// Adapts any async callback (such as Firestore, Supabase, or your own API)
/// into a [FeedbackSink] without adding backend dependencies to this package.
///
/// Example with Firestore:
/// ```dart
/// final sink = CallbackFeedbackSink((report) async {
///   await FirebaseFirestore.instance.collection('feedback').add(report.toJson());
/// });
/// ```
class CallbackFeedbackSink extends FeedbackSink {
  const CallbackFeedbackSink(this.onSend);

  final Future<void> Function(FeedbackReport report) onSend;

  @override
  Future<void> send(FeedbackReport report) => onSend(report);
}

/// Delivers [FeedbackReport] as a JSON `POST` to any HTTPS webhook (Cloudflare
/// Worker, Slack/Discord webhook proxy, Make, n8n, Google Apps Script, etc.).
class WebhookFeedbackSink extends FeedbackSink {
  WebhookFeedbackSink(
    this.url, {
    this.headers = const <String, String>{},
    this.timeout = const Duration(seconds: 10),
    this.payloadBuilder,
    http.Client? client,
  }) : _client = client;

  final String url;
  final Map<String, String> headers;
  final Duration timeout;

  /// Optional custom JSON payload formatter (defaults to `report.toJson()`).
  final Map<String, dynamic> Function(FeedbackReport report)? payloadBuilder;
  final http.Client? _client;

  @override
  Future<void> send(FeedbackReport report) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw FeedbackDeliveryException('Invalid webhook URL: "$url"');
    }

    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final body = jsonEncode(
        payloadBuilder != null ? payloadBuilder!(report) : report.toJson(),
      );
      final response = await client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              ...headers,
            },
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FeedbackDeliveryException(
          'Webhook returned error status',
          statusCode: response.statusCode,
        );
      }
    } on FeedbackDeliveryException {
      rethrow;
    } on TimeoutException catch (e) {
      throw FeedbackDeliveryException(
        'Webhook timed out after ${timeout.inSeconds}s',
        cause: e,
      );
    } catch (e) {
      throw FeedbackDeliveryException('Webhook request failed: $e', cause: e);
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}

/// Sends a formatted feedback alert to a Telegram chat via Telegram Bot API.
///
/// Security note: for public apps, prefer routing through a tiny Cloudflare
/// Worker with [WebhookFeedbackSink] rather than embedding a raw bot token in
/// client binaries.
class TelegramFeedbackSink extends FeedbackSink {
  TelegramFeedbackSink({
    required this.botToken,
    required this.chatId,
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  }) : _client = client;

  final String botToken;
  final String chatId;
  final Duration timeout;
  final http.Client? _client;

  @override
  Future<void> send(FeedbackReport report) async {
    final uri = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'chat_id': chatId,
              'text': report.toFormattedText(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FeedbackDeliveryException(
          'Telegram API rejected feedback',
          statusCode: response.statusCode,
        );
      }
    } on FeedbackDeliveryException {
      rethrow;
    } catch (e) {
      throw FeedbackDeliveryException('Telegram delivery failed: $e', cause: e);
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}

/// Zero-server fallback that opens the user's email client (`mailto:`)
/// pre-filled with the feedback report and diagnostics.
class EmailFeedbackSink extends FeedbackSink {
  const EmailFeedbackSink({
    required this.toEmail,
    this.subjectPrefix = 'App Feedback',
  });

  final String toEmail;
  final String subjectPrefix;

  @override
  Future<void> send(FeedbackReport report) async {
    final subject =
        '$subjectPrefix — ${report.diagnostics.appName} (${report.rating}/5)';
    final body = report.toFormattedText();
    final uri = Uri(
      scheme: 'mailto',
      path: toEmail.trim(),
      query: _encodeQuery(<String, String>{
        'subject': subject,
        'body': body,
      }),
    );
    final launched = await launchUrl(uri);
    if (!launched) {
      throw const FeedbackDeliveryException('No email app available on device');
    }
  }

  static String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}

/// Delivers feedback to multiple sinks concurrently (succeeds if at least one
/// succeeds when [requireAll] is `false`).
class MultiFeedbackSink extends FeedbackSink {
  const MultiFeedbackSink(this.sinks, {this.requireAll = false});

  final List<FeedbackSink> sinks;
  final bool requireAll;

  @override
  Future<void> send(FeedbackReport report) async {
    if (sinks.isEmpty) return;
    final errors = <Object>[];
    var successes = 0;
    for (final FeedbackSink sink in sinks) {
      try {
        await sink.send(report);
        successes++;
      } catch (e) {
        errors.add(e);
      }
    }
    if (requireAll && errors.isNotEmpty) {
      throw FeedbackDeliveryException(
        'One or more feedback sinks failed (${errors.length}/${sinks.length})',
        cause: errors.first,
      );
    }
    if (successes == 0 && errors.isNotEmpty) {
      throw FeedbackDeliveryException(
        'All feedback sinks failed',
        cause: errors.first,
      );
    }
  }
}

/// In-memory sink for tests and local demos.
class MemoryFeedbackSink extends FeedbackSink {
  MemoryFeedbackSink({this.errorToThrow});

  final List<FeedbackReport> reports = <FeedbackReport>[];
  Object? errorToThrow;

  @override
  Future<void> send(FeedbackReport report) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    reports.add(report);
  }
}
