import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class ParticipatingTheatersScreen extends StatelessWidget {
  const ParticipatingTheatersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Participating Theaters'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: FutureBuilder<List<CinemaModel>>(
        future: ApiClient.instance.getCinemas(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.crimson));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.crimson),
                ),
              ),
            );
          }
          final cinemas = snap.data ?? [];
          if (cinemas.isEmpty) {
            return const Center(
              child: Text(
                'No participating theaters found.',
                style: TextStyle(color: AppTheme.inkSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cinemas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = cinemas[i];
              final halls = c.auditoriums
                  .map((a) => '${a.name} (${a.totalRows}×${a.totalCols})')
                  .join(' • ');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.crimsonTint,
                          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(Icons.theaters_outlined, color: AppTheme.crimson, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${c.address}, ${c.city}, ${c.state}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppTheme.inkSecondary, height: 1.35),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.canvasMuted,
                                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                'Halls: ${halls.isEmpty ? "Coming soon" : halls}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.tabular(
                                  const TextStyle(
                                    color: AppTheme.inkPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
