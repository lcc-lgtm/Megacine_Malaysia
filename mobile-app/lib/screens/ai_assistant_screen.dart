import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
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
      text: 'Hi! I am Megacine AI Concierge. Ask me for movie picks, showtimes, refund rules, or your recent orders!',
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
          _scrollCtrl.position.maxScrollExtent + 120,
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
      'What are the refund & seat hold rules?',
      'Check my recent orders status',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Megacine AI'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedModel,
              dropdownColor: const Color(0xFF1E293B),
              items: _models
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() { _selectedModel = v ?? _selectedModel; }),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: quickPrompts
                  .map((q) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(q, style: const TextStyle(fontSize: 12)), onPressed: () => _send(q)),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (_thinking && i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('AI is thinking...', style: TextStyle(color: Colors.grey)),
                      ]),
                    ),
                  );
                }
                final msg = _messages[i];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.blueAccent : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.text, style: const TextStyle(height: 1.4)),
                        if (msg.modelUsed != null) ...[
                          const SizedBox(height: 6),
                          Text('Model: ${msg.modelUsed}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                        if (msg.movies.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...msg.movies.map((m) => Card(
                                color: const Color(0xFF0F172A),
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.movie, color: Colors.amber),
                                  title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${m.genre ?? "Cinema"} • ${m.durationMinutes}m'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FilmDetailScreen(
                                        movie: m,
                                        initiallyBookmarked: widget.bookmarkedIds.contains(m.id),
                                      ),
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
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask AI about movies, showtimes, or refunds...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _thinking ? null : () => _send(_ctrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
