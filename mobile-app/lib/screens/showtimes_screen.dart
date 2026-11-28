import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'seat_map_screen.dart';

class ShowtimesScreen extends StatefulWidget {
  final MovieModel movie;
  const ShowtimesScreen({super.key, required this.movie});

  @override
  State<ShowtimesScreen> createState() => _ShowtimesScreenState();
}

class _ShowtimesScreenState extends State<ShowtimesScreen> {
  late Future<List<dynamic>> _future;
  bool _ignoreLocationFilter = false;

  @override
  void initState() {
    super.initState();
    _future = Future.wait([
      ApiClient.instance.getShowtimes(widget.movie.id),
      ApiClient.instance.getCinemas(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ApiClient.instance.selectedLocation;
    return Scaffold(
      appBar: AppBar(
        title: Text('Screenings — ${widget.movie.title}'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.crimson),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: AppTheme.crimson),
                    const SizedBox(height: 12),
                    Text('Failed to load screenings', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('${snap.error}'.replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.inkSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _future = Future.wait([
                            ApiClient.instance.getShowtimes(widget.movie.id),
                            ApiClient.instance.getCinemas(),
                          ]);
                        });
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allShowtimes = snap.data![0] as List<ShowtimeModel>;
          final cinemas = snap.data![1] as List<CinemaModel>;
          final cinemaById = {for (final c in cinemas) c.id: c};

          final filtered = (_ignoreLocationFilter || loc == 'All Locations')
              ? allShowtimes
              : allShowtimes.where((st) => cinemaById[st.cinemaId]?.city == loc).toList();

          return Column(
            children: [
              // Warm paper location filter bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.canvasMuted,
                  border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppTheme.crimson),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location: ${_ignoreLocationFilter ? "All Locations" : loc}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.inkPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loc != 'All Locations')
                      TextButton(
                        onPressed: () => setState(() { _ignoreLocationFilter = !_ignoreLocationFilter; }),
                        child: Text(_ignoreLocationFilter ? 'Filter by $loc' : 'Show All Cities'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.movie_outlined, size: 48, color: AppTheme.inkMuted),
                              const SizedBox(height: 12),
                              Text('No screenings found in $loc.',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.inkPrimary)),
                              if (allShowtimes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() { _ignoreLocationFilter = true; }),
                                  child: const Text('View screenings in other locations'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final st = filtered[i];
                          final c = cinemaById[st.cinemaId];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${st.cinemaName} — ${st.auditoriumName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: AppTheme.inkPrimary,
                                              ),
                                            ),
                                            if (c != null) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                '${c.address}, ${c.city}, ${c.state}',
                                                style: const TextStyle(color: AppTheme.inkSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.amberTint,
                                          border: Border.all(color: AppTheme.amber, width: 1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'MYR ${st.basePrice.toStringAsFixed(2)}',
                                          style: AppTheme.tabular(
                                            const TextStyle(
                                              color: AppTheme.inkPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 15, color: AppTheme.inkSecondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            formatMYT(st.startTime),
                                            style: AppTheme.tabular(
                                              const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.inkPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => SeatMapScreen(showtime: st)),
                                        ),
                                        child: const Text('Select Seats'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
