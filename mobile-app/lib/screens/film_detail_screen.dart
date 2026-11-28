import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'showtimes_screen.dart';
import 'trailer_player_screen.dart';

class FilmDetailScreen extends StatefulWidget {
  final MovieModel movie;
  final bool initiallyBookmarked;
  const FilmDetailScreen({super.key, required this.movie, required this.initiallyBookmarked});

  @override
  State<FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<FilmDetailScreen> {
  late bool _bookmarked;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.initiallyBookmarked;
  }

  Future<void> _toggleBookmark() async {
    setState(() { _toggling = true; });
    try {
      await ApiClient.instance.toggleBookmark(widget.movie.id, _bookmarked);
      if (mounted) {
        setState(() { _bookmarked = !_bookmarked; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_bookmarked ? 'Bookmarked! Future recommendations updated.' : 'Removed from bookmarks.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() { _toggling = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final hasTrailer = m.trailerUrl != null && m.trailerUrl!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.title),
        actions: [
          IconButton(
            tooltip: _bookmarked ? 'Remove Bookmark' : 'Bookmark Film',
            icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border, color: _bookmarked ? Colors.amber : null),
            onPressed: _toggling ? null : _toggleBookmark,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 230,
              color: const Color(0xFF1E293B),
              child: m.posterUrl != null && m.posterUrl!.isNotEmpty
                  ? Image.network(m.posterUrl!, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie_creation, size: 72, color: Colors.blueAccent)))
                  : const Center(child: Icon(Icons.movie_creation, size: 72, color: Colors.blueAccent)),
            ),
          ),
          const SizedBox(height: 16),
          Text(m.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (m.genre != null && m.genre!.isNotEmpty) Chip(label: Text(m.genre!), backgroundColor: Colors.blueAccent.withOpacity(0.2)),
              Chip(label: Text('${m.durationMinutes} mins')),
              Chip(label: Text(m.language)),
              Chip(label: Text(m.rating ?? 'NR')),
              if (m.releaseDate != null) Chip(label: Text('Release: ${m.releaseDate}')),
            ],
          ),
          const SizedBox(height: 16),
          if (hasTrailer)
            OutlinedButton.icon(
              icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent),
              label: const Text('Watch Official Trailer (YouTube)'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TrailerPlayerScreen(title: m.title, trailerUrl: m.trailerUrl!)),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Synopsis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(m.synopsis?.isNotEmpty == true ? m.synopsis! : 'No synopsis available for this film.',
              style: const TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.event_seat),
            label: const Text('View Screenings & Book Seats'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ShowtimesScreen(movie: m)),
            ),
          ),
        ],
      ),
    );
  }
}
