import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'film_detail_screen.dart';

class _ChatBubble {
  final bool isUser;
  final String text;
  final String? modelUsed;
  final List<MovieModel> movies;
  _ChatBubble({required this.isUser, required this.text, this.modelUsed, this.movies = const []});
}

class AiAssistantScreen extends StatefulWidget {
  final List<MovieModel> allMovies;
  final Set<String> bookmarkedIds;
  final String? initialPrompt;

  const AiAssistantScreen({
    super.key,
    required this.allMovies,
    required this.bookmarkedIds,
    this.initialPrompt,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatBubble> _messages = [
    _ChatBubble(
      isUser: false,
      text: 'Welcome to English Cinema Concierge. I am your Gemini-powered AI film advisor. Ask me for personalized recommendations, showtimes, refund policy, or your active bookings!',
    ),
  ];
  bool _thinking = false;
  String _selectedModel = 'gemini-3.8-flash';
  static const List<String> _models = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-4-hydrogen',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.initialPrompt!));
    }
  }

  Future<void> _send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || _thinking) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_ChatBubble(isUser: true, text: text));
      _thinking = true;
    });
    _scrollToBottom();

    try {
      final res = await ApiClient.instance.aiChat(
        text,
        location: ApiClient.instance.selectedLocation,
        model: _selectedModel,
      );
      final reply = (res['reply'] ?? 'Done.').toString();
      final modelUsed = res['model_used']?.toString();
      final cfg = (res['config'] as Map<String, dynamic>?) ?? {};
      final recIds = List<String>.from(cfg['recommended_movie_ids'] ?? []);
      final byId = {for (final m in widget.allMovies) m.id: m};
      final matchedMovies = recIds.where(byId.containsKey).map((id) => byId[id]!).toList();

      if (mounted) {
        setState(() {
          _messages.add(_ChatBubble(
            isUser: false,
            text: reply,
            modelUsed: modelUsed,
            movies: matchedMovies,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatBubble(
            isUser: false,
            text: 'Error: ${e.toString().replaceFirst("Exception: ", "")}',
          ));
        });
      }
    } finally {
      if (mounted) setState(() { _thinking = false; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const quickPrompts = [
      'Recommend a movie based on my bookmarks',
      'What are the 60m refund & seat hold rules?',
      'Check my recent orders status',
      'Top sci-fi or action films playing this week',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: AppTheme.crimson),
            const SizedBox(width: 8),
            const Text('English Cinema Concierge'),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.canvasMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedModel,
                dropdownColor: AppTheme.surface,
                icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.inkPrimary),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.inkPrimary),
                items: _models
                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) => setState(() { _selectedModel = v ?? _selectedModel; }),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick prompt chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.canvasMuted,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: quickPrompts
                    .map((q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            backgroundColor: AppTheme.surface,
                            side: const BorderSide(color: AppTheme.border),
                            label: Text(q, style: const TextStyle(fontSize: 12, color: AppTheme.inkPrimary)),
                            onPressed: () => _send(q),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (_thinking && i == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.crimson)),
                          SizedBox(width: 10),
                          Text('Gemini AI is analyzing...', style: TextStyle(color: AppTheme.inkSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[i];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppTheme.inkPrimary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      border: msg.isUser ? null : Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: msg.isUser ? Colors.white : AppTheme.inkPrimary,
                          ),
                        ),
                        if (msg.modelUsed != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 12, color: msg.isUser ? AppTheme.amber : AppTheme.crimson),
                              const SizedBox(width: 4),
                              Text(
                                'Engine: ${msg.modelUsed}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: msg.isUser ? Colors.white70 : AppTheme.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (msg.movies.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...msg.movies.map((m) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FilmDetailScreen(
                                        movie: m,
                                        initiallyBookmarked: widget.bookmarkedIds.contains(m.id),
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.canvasMuted,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.movie_creation_outlined, size: 20, color: AppTheme.crimson),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.title,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.inkPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${m.genre ?? "Cinema"} • ${m.durationMinutes}m',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.inkSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, size: 18, color: AppTheme.inkSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Input bar with SafeArea
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ask concierge about films, showtimes, or rules...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.crimson,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInner)),
                      ),
                      onPressed: _thinking ? null : () => _send(_ctrl.text),
                      child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
