import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      if (mounted) setState(() { _toggling = false; });
    }
  }

  Widget _metaChip(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? AppTheme.crimsonTint : AppTheme.canvasMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: accent ? AppTheme.crimson.withValues(alpha: 0.35) : AppTheme.border),
      ),
      child: Text(
        text,
        style: AppTheme.tabular(
          TextStyle(
            fontSize: 12,
            fontWeight: accent ? FontWeight.w600 : FontWeight.w500,
            color: accent ? AppTheme.crimsonPressed : AppTheme.inkPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final hasTrailer = m.trailerUrl != null && m.trailerUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(
          m.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _bookmarked ? 'Remove Bookmark' : 'Bookmark Film',
            icon: Icon(
              _bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _bookmarked ? AppTheme.amber : AppTheme.inkPrimary,
            ),
            onPressed: _toggling ? null : _toggleBookmark,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppTheme.canvasMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: m.posterUrl != null && m.posterUrl!.isNotEmpty
                  ? Image.network(
                      m.posterUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.movie_creation_outlined, size: 64, color: AppTheme.inkMuted),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.movie_creation_outlined, size: 64, color: AppTheme.inkMuted),
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              m.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppTheme.inkPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (m.genre != null && m.genre!.isNotEmpty) _metaChip(m.genre!, accent: true),
                _metaChip('${m.durationMinutes} min'),
                _metaChip(m.language),
                _metaChip(m.rating ?? 'NR'),
                if (m.releaseDate != null) _metaChip('Release: ${m.releaseDate}'),
              ],
            ),
            if (hasTrailer) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                icon: const Icon(Icons.play_circle_outline, color: AppTheme.crimson),
                label: const Text('Watch Official Trailer (YouTube)'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrailerPlayerScreen(title: m.title, trailerUrl: m.trailerUrl!),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SYNOPSIS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m.synopsis?.isNotEmpty == true ? m.synopsis! : 'No synopsis available for this film.',
                      style: const TextStyle(
                        color: AppTheme.inkSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.event_seat_outlined),
              label: const Text('View Screenings & Book Seats'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ShowtimesScreen(movie: m)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
