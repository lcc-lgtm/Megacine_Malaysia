import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../utils/password_helper.dart';

class TrailerPlayerScreen extends StatefulWidget {
  final String title;
  final String trailerUrl;
  const TrailerPlayerScreen({super.key, required this.title, required this.trailerUrl});

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  YoutubePlayerController? _ytController;
  String? _videoId;

  bool get _supportsInlineIframe =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _videoId = PasswordHelper.extractYoutubeId(widget.trailerUrl);
    if (_videoId != null && _supportsInlineIframe) {
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: _videoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true, mute: false),
      );
    }
  }

  @override
  void dispose() {
    _ytController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} — Trailer')),
      body: Center(
        child: _ytController != null
            ? AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _ytController!),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_videoId != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://img.youtube.com/vi/$_videoId/hqdefault.jpg',
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.ondemand_video, size: 80, color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Desktop preview launches YouTube directly in your browser.',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play Trailer on YouTube'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => launchUrl(Uri.parse(widget.trailerUrl), mode: LaunchMode.externalApplication),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
