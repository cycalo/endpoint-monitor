import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../feedback/feedback_form.dart';
import '../feedback/formspree_feedback_client.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_gradient_button.dart';
import '../widgets/em_loading_states.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.submitFeedback});

  /// Defaults to the ENDPOINT-MONITOR Formspree form. Injected in tests.
  final Future<void> Function(FeedbackDraft draft)? submitFeedback;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  final _email = TextEditingController();
  final _client = FormspreeFeedbackClient();

  FeedbackCategory _category = FeedbackCategory.idea;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  FeedbackDraft get _draft => FeedbackDraft(
        category: _category,
        message: _message.text,
        email: _email.text,
      );

  Future<void> _submit() async {
    if (_busy) return;
    final localError = validateFeedbackDraft(_draft);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final send = widget.submitFeedback ?? _client.submit;
      await send(_draft);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
    } on FeedbackValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on FeedbackSubmitException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = kFeedbackSubmitFailedMessage;
      });
    }
  }

  void _reset() {
    _message.clear();
    _email.clear();
    setState(() {
      _category = FeedbackCategory.idea;
      _sent = false;
      _error = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomInset),
        children: [
          const EmPageIntro(
            title: 'Send feedback',
            subtitle:
                'Ideas, bugs, or anything else. Email is optional if you want a follow-up.',
            padding: EdgeInsets.only(bottom: 16),
          ),
          if (_sent) ...[
            Container(
              padding: const EdgeInsets.all(EmDesign.spaceLg),
              decoration: EmDesign.cardShell(
                scheme,
                color: scheme.primaryContainer.withValues(alpha: 0.22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: scheme.tertiary,
                    size: 36,
                  ),
                  const SizedBox(height: EmDesign.spaceSm),
                  Text(
                    'Thanks — we got your feedback.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No endpoint data was attached. Only what you typed is sent.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: EmDesign.spaceMd),
                  OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Send another'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text('WHAT IS THIS ABOUT',
                style: EmDesign.labelCaps(context, scheme)),
            const SizedBox(height: 8),
            SegmentedButton<FeedbackCategory>(
              segments: const [
                ButtonSegment(
                  value: FeedbackCategory.idea,
                  label: Text('Idea'),
                ),
                ButtonSegment(
                  value: FeedbackCategory.bug,
                  label: Text('Bug'),
                ),
                ButtonSegment(
                  value: FeedbackCategory.other,
                  label: Text('Other'),
                ),
              ],
              selected: {_category},
              onSelectionChanged: _busy
                  ? null
                  : (selected) {
                      setState(() => _category = selected.first);
                    },
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
            ),
            const SizedBox(height: EmDesign.spaceLg),
            Text('MESSAGE', style: EmDesign.labelCaps(context, scheme)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('feedback-message'),
              controller: _message,
              enabled: !_busy,
              minLines: 5,
              maxLines: 10,
              maxLength: kFeedbackMessageMaxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: _category == FeedbackCategory.bug
                    ? 'What happened, and what did you expect?'
                    : 'What should we know?',
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
              ),
            ),
            const SizedBox(height: EmDesign.spaceMd),
            Text('EMAIL (OPTIONAL)',
                style: EmDesign.labelCaps(context, scheme)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('feedback-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                  color: scheme.outline,
                  size: 20,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Only used if we need to follow up. Leave blank to send anonymously.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                fontSize: 11,
                height: 1.35,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: EmDesign.spaceMd),
              EmStatusPanel(
                icon: Icons.error_outline_rounded,
                message: _error!,
              ),
            ],
            const SizedBox(height: EmDesign.spaceLg),
            EmGradientButton(
              label: _busy ? 'Sending…' : 'Send feedback',
              icon: Icons.send_rounded,
              inProgress: _busy,
              onPressed: _busy
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _submit();
                    },
            ),
          ],
        ],
      ),
    );
  }
}
