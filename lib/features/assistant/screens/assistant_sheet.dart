import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../data/assistant_api.dart';

/// The top button that opens the assistant. [courseId] and [sectionId] say which
/// course is open, and [onChanged] runs after a confirmed change, so the screen behind can reload.
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key, this.courseId, this.sectionId, this.onChanged});

  final String? courseId;
  final String? sectionId;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Assistant',
      icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.text),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => AssistantSheet(courseId: courseId, sectionId: sectionId, onChanged: onChanged),
      ),
    );
  }
}

/// One line of the chat. Replies also carry their numbers and any change waiting for Confirm.
class _Message {
  _Message.teacher(this.text)
      : fromTeacher = true,
        proposals = const [],
        stats = const [];

  _Message.reply(AssistantReply reply)
      : fromTeacher = false,
        text = reply.text,
        proposals = reply.proposals,
        stats = reply.stats;

  final bool fromTeacher;
  final String text;
  final List<Proposal> proposals;
  final List<ReplyStat> stats;
}

/// The chat. Nothing is saved: closing the sheet ends the conversation.
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key, this.courseId, this.sectionId, this.onChanged});

  final String? courseId;
  final String? sectionId;
  final VoidCallback? onChanged;

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  static const _suggestions = ['What classes do I have today?', 'Who is short on attendance?', 'Am I behind on my plan?'];

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  final _messages = <_Message>[];
  bool _thinking = false;
  String? _error; // set when the last question failed; the question stays so it can be tried again
  bool _listening = false;
  String? _voiceNote;

  @override
  void dispose() {
    _speech.cancel().ignore();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String typed) {
    final message = typed.trim();
    if (message.isEmpty || _thinking) return;
    _text.clear();
    setState(() => _messages.add(_Message.teacher(message)));
    _ask();
  }

  /// Asks the last message. Everything before it is the history, so a retry sends exactly the same thing.
  Future<void> _ask() async {
    setState(() {
      _thinking = true;
      _error = null;
    });
    _scrollToEnd();
    final question = _messages.last.text;
    final history = [
      for (final item in _messages.take(_messages.length - 1)) ChatTurn(fromTeacher: item.fromTeacher, text: item.text),
    ];
    try {
      final reply = await AssistantApi.ask(question, history: history, courseId: widget.courseId, sectionId: widget.sectionId);
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(_Message.reply(reply));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _error = '$error';
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Voice fills the box and stops there. The teacher reads it first, because a misheard word is easy to miss.
  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final typedBefore = _text.text.trim();
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (mounted && status != 'listening') setState(() => _listening = false);
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (!mounted) return;
      if (!ready) {
        setState(() => _voiceNote = 'Voice needs microphone permission. You can type instead.');
        return;
      }
      setState(() {
        _listening = true;
        _voiceNote = null;
      });
      await _speech.listen(
        onResult: (result) {
          final words = [if (typedBefore.isNotEmpty) typedBefore, result.recognizedWords].join(' ');
          _text.value = TextEditingValue(text: words, selection: TextSelection.collapsed(offset: words.length));
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceNote = 'Voice isn\'t available here. You can type instead.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the box above the phone's keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Assistant', style: AppText.screenTitle),
                const SizedBox(height: 12),
                Expanded(
                  child: _messages.isEmpty
                      ? _Suggestions(items: _suggestions, onTap: _send)
                      : ListView(
                          controller: _scroll,
                          children: [
                            for (final message in _messages)
                              message.fromTeacher ? _TeacherBubble(text: message.text) : _Reply(message: message, onChanged: widget.onChanged),
                            if (_thinking) const _Thinking(),
                            if (_error != null) _Failed(message: _error!, onRetry: _ask),
                          ],
                        ),
                ),
                if (_voiceNote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_voiceNote!, style: AppText.small.copyWith(color: AppColors.textMuted)),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        style: AppText.input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        // The backend's limit.
                        inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                        decoration: InputDecoration(hintText: _listening ? 'Listening…' : 'Ask anything'),
                        onSubmitted: _send,
                      ),
                    ),
                    IconButton(
                      tooltip: _listening ? 'Stop listening' : 'Speak',
                      icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: _listening ? AppColors.green : AppColors.textMuted),
                      onPressed: _toggleVoice,
                    ),
                    IconButton(
                      tooltip: 'Send',
                      icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.green),
                      onPressed: _thinking ? null : () => _send(_text.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Before the first question: one tap instead of typing.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Ask about your classes in your own words.', style: AppText.body.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final item in items) ActionChip(label: Text(item), onPressed: () => onTap(item))],
        ),
      ],
    );
  }
}

class _TeacherBubble extends StatelessWidget {
  const _TeacherBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: const BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(text, style: AppText.rowTitle.copyWith(color: AppColors.onGreen)),
        ),
      ),
    );
  }
}

class _Reply extends StatelessWidget {
  const _Reply({required this.message, required this.onChanged});

  final _Message message;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(message.text, style: AppText.body.copyWith(fontSize: 16)),
          if (message.stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (index, stat) in message.stats.indexed) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(child: _StatTile(stat: stat)),
                ],
              ],
            ),
          ],
          for (final proposal in message.proposals) ...[
            const SizedBox(height: 12),
            _ProposalCard(proposal: proposal, onChanged: onChanged),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final ReplyStat stat;

  @override
  Widget build(BuildContext context) {
    final colour = switch (stat.tone) {
      'warning' => AppColors.warning,
      'good' => AppColors.green,
      _ => AppColors.text,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.value, style: AppText.cardTitle.copyWith(color: colour, fontSize: 26)),
          const SizedBox(height: 2),
          Text(stat.label, style: AppText.label.copyWith(fontSize: 11, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

/// A change waiting for the teacher. This tap is the only thing that can make it happen.
class _ProposalCard extends StatefulWidget {
  const _ProposalCard({required this.proposal, required this.onChanged});

  final Proposal proposal;
  final VoidCallback? onChanged;

  @override
  State<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<_ProposalCard> {
  bool _busy = false;
  bool _done = false;
  bool _declined = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AssistantApi.confirm(widget.proposal);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.proposal.title, style: AppText.rowTitle),
          const SizedBox(height: 4),
          Text(widget.proposal.detail, style: AppText.small.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          if (_done)
            Row(
              children: [
                const Icon(Icons.check_rounded, size: 18, color: AppColors.successText),
                const SizedBox(width: 6),
                Text('Done', style: AppText.rowTitle.copyWith(color: AppColors.successText)),
              ],
            )
          else if (_declined)
            Text('Left as it was', style: AppText.small.copyWith(color: AppColors.textMuted))
          else ...[
            if (_error != null) ...[
              Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _busy ? null : () => setState(() => _declined = true), child: const Text('Not now')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: _busy ? null : _confirm, child: Text(_busy ? 'Saving…' : 'Confirm')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Dots while waiting. An answer can take a while, so the screen must show it's still working.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> with SingleTickerProviderStateMixin {
  late final _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: 'The assistant is thinking',
        child: AnimatedBuilder(
          animation: _dots,
          builder: (context, _) => Text(
            '.' * (1 + (_dots.value * 3).floor().clamp(0, 2)),
            style: AppText.screenTitle.copyWith(color: AppColors.green),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppText.body.copyWith(color: AppColors.dangerText)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
