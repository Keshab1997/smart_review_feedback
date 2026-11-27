import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_review_feedback/smart_review_feedback.dart';

void main() {
  runApp(const SmartReviewExampleApp());
}

class SmartReviewExampleApp extends StatefulWidget {
  const SmartReviewExampleApp({super.key});

  @override
  State<SmartReviewExampleApp> createState() => _SmartReviewExampleAppState();
}

class _SmartReviewExampleAppState extends State<SmartReviewExampleApp> {
  final MemoryFeedbackSink _sink = MemoryFeedbackSink();
  late final SmartReviewController _controller;
  bool _bangla = false;

  @override
  void initState() {
    super.initState();
    _controller = SmartReviewController(
      feedbackSink: _sink,
      storage: InMemoryReviewStorage(),
      storeAdapter: FakeStoreReviewAdapter(),
      appName: 'Demo App',
      appVersion: '1.0.0',
      buildNumber: '1',
      rules: const ReviewTriggerRules(
        minDaysSinceInstall: 0,
        minLaunchCount: 1,
        minPositiveEvents: 2,
      ),
    );
    unawaited(_controller.init());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _bangla
        ? const ReviewStrings.bn(appName: 'ডেমো অ্যাপ')
        : const ReviewStrings.en(appName: 'Demo App');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('smart_review_feedback Demo'),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() => _bangla = !_bangla),
                child: Text(_bangla ? 'EN' : 'বাংলা'),
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext _, Widget? __) => ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: ListTile(
                    title: Text(
                      'Positive events: ${_controller.state.positiveEventCount}',
                    ),
                    subtitle: Text(
                      'Eligible now: ${_controller.shouldPromptNow}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    await _controller.recordPositiveEvent();
                    if (!ctx.mounted) return;
                    await _controller.maybePrompt(
                      ctx,
                      strings: strings,
                      screenName: 'DemoHome',
                    );
                    if (mounted) setState(() {});
                  },
                  child: const Text('Record happy moment (maybePrompt)'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await _controller.showNow(
                      ctx,
                      strings: strings,
                      screenName: 'SettingsScreen',
                    );
                    if (mounted) setState(() {});
                  },
                  child: const Text('Open Rating Sheet now'),
                ),
                const SizedBox(height: 16),
                Text('Captured feedback reports: ${_sink.reports.length}'),
                for (final FeedbackReport r in _sink.reports)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(r.toFormattedText()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
