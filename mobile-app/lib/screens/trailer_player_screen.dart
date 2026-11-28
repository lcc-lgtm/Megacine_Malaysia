import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../theme/app_theme.dart';
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
      backgroundColor: AppTheme.darkStage,
      appBar: AppBar(
        backgroundColor: AppTheme.darkStage,
        foregroundColor: AppTheme.canvas,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.canvas),
        title: Text(
          '${widget.title} — Trailer',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.canvas, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.darkStageBorder),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _ytController != null
              ? Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppTheme.darkStageBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(controller: _ytController!),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222120),
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: AppTheme.darkStageBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_videoId != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                              child: Image.network(
                                'https://img.youtube.com/vi/$_videoId/hqdefault.jpg',
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Icon(Icons.ondemand_video, size: 72, color: AppTheme.crimson),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.canvas,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Desktop preview launches YouTube directly in your browser.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.inkMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play Trailer on YouTube'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.crimson,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            onPressed: () => launchUrl(
                              Uri.parse(widget.trailerUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
