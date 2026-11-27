import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/smart_review_controller.dart';
import '../models/review_strings.dart';

enum _SheetStep { rate, feedback, thankYouStore, thankYouFeedback }

/// 2-step Material 3 bottom sheet for smart rating & feedback collection.
///
/// - Ratings `>= controller.rules.minStoreRating` (default 4–5 stars) route to
///   Google Play / App Store In-App Review.
/// - Lower ratings (1–3 stars) open a structured in-app feedback form with
///   auto-attached diagnostics instead of sending frustrated users to the store.
class SmartReviewSheet extends StatefulWidget {
  const SmartReviewSheet({
    super.key,
    required this.controller,
    this.strings = const ReviewStrings.en(),
    this.screenName,
    this.extraDiagnostics = const <String, Object?>{},
  });

  final SmartReviewController controller;
  final ReviewStrings strings;
  final String? screenName;
  final Map<String, Object?> extraDiagnostics;

  /// Opens [SmartReviewSheet] as a modal bottom sheet.
  static Future<SmartReviewOutcome?> show(
    BuildContext context, {
    required SmartReviewController controller,
    ReviewStrings strings = const ReviewStrings.en(),
    String? screenName,
    Map<String, Object?> extraDiagnostics = const <String, Object?>{},
  }) {
    return showModalBottomSheet<SmartReviewOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SmartReviewSheet(
            controller: controller,
            strings: strings,
            screenName: screenName,
            extraDiagnostics: extraDiagnostics,
          ),
        );
      },
    );
  }

  @override
  State<SmartReviewSheet> createState() => _SmartReviewSheetState();
}

class _SmartReviewSheetState extends State<SmartReviewSheet> {
  _SheetStep _step = _SheetStep.rate;
  int _selectedRating = 0;
  final Set<String> _selectedCategories = <String>{};
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _onContinueFromRating() async {
    if (_selectedRating == 0) return;
    if (_selectedRating >= widget.controller.rules.minStoreRating) {
      setState(() => _isSubmitting = true);
      try {
        await widget.controller.triggerStoreReview();
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _step = _SheetStep.thankYouStore;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _step = _SheetStep.thankYouStore;
        });
      }
    } else {
      setState(() {
        _errorText = null;
        _step = _SheetStep.feedback;
      });
    }
  }

  Future<void> _onSubmitFeedback() async {
    final msg = _messageController.text.trim();
    if (_selectedCategories.isEmpty && msg.isEmpty) {
      setState(() => _errorText = widget.strings.emptyMessageError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
      await widget.controller.submitFeedback(
        rating: _selectedRating,
        categories: _selectedCategories.toList(growable: false),
        message: msg,
        contact: _contactController.text.trim(),
        screenName: widget.screenName,
        locale: locale,
        extraDiagnostics: widget.extraDiagnostics,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _step = _SheetStep.thankYouFeedback;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = widget.strings.submitErrorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buildCurrentStep(context),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_step) {
      case _SheetStep.rate:
        return _buildRateStep(context);
      case _SheetStep.feedback:
        return _buildFeedbackStep(context);
      case _SheetStep.thankYouStore:
        return _buildThankYouStep(
          context,
          message: widget.strings.thankYouStoreMessage,
          outcome: SmartReviewOutcome.routedToStore,
          showOpenStore: true,
        );
      case _SheetStep.thankYouFeedback:
        return _buildThankYouStep(
          context,
          message: widget.strings.thankYouFeedbackMessage,
          outcome: SmartReviewOutcome.submittedFeedback,
          showOpenStore: false,
        );
    }
  }

  Widget _buildRateStep(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = widget.strings;

    return Column(
      key: const ValueKey<String>('step_rate'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: colors.onPrimaryContainer,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.rateTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.rateSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(5, (int index) {
            final starValue = index + 1;
            final active = starValue <= _selectedRating;
            return IconButton(
              key: ValueKey<String>('review_star_$starValue'),
              iconSize: 40,
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() => _selectedRating = starValue),
              icon: Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                color: active
                    ? const Color(0xFFF59E0B)
                    : colors.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            );
          }),
        ),
        SizedBox(
          height: 24,
          child: _selectedRating > 0
              ? Text(
                  s.starLabels[_selectedRating - 1],
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context)
                        .pop(SmartReviewOutcome.dismissed),
                child: Text(s.notNowButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (_selectedRating == 0 || _isSubmitting)
                    ? null
                    : () => unawaited(_onContinueFromRating()),
                child: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Text(s.continueButton),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackStep(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = widget.strings;

    return Column(
      key: const ValueKey<String>('step_feedback'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          s.feedbackTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.feedbackSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: s.categories.map((String cat) {
            final selected = _selectedCategories.contains(cat);
            return FilterChip(
              label: Text(cat),
              selected: selected,
              onSelected: _isSubmitting
                  ? null
                  : (bool next) {
                      setState(() {
                        if (next) {
                          _selectedCategories.add(cat);
                        } else {
                          _selectedCategories.remove(cat);
                        }
                        _errorText = null;
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey<String>('feedback_message_field'),
          controller: _messageController,
          maxLines: 3,
          minLines: 2,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: s.messageHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey<String>('feedback_contact_field'),
          controller: _contactController,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: s.contactHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.diagnosticsNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (_errorText != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            _errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() => _step = _SheetStep.rate),
              child: Text(s.backButton),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () => unawaited(_onSubmitFeedback()),
              icon: _isSubmitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? s.submittingLabel : s.submitButton,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThankYouStep(
    BuildContext context, {
    required String message,
    required SmartReviewOutcome outcome,
    required bool showOpenStore,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = widget.strings;

    return Column(
      key: ValueKey<String>('step_done_${outcome.name}'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 32,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.thankYouTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        if (showOpenStore) ...<Widget>[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                unawaited(widget.controller.openStoreListing());
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(s.openStoreButton),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(outcome),
            child: Text(s.doneButton),
          ),
        ),
      ],
    );
  }
}
