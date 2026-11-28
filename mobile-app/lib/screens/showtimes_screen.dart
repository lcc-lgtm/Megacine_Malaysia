import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
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
      appBar: AppBar(title: Text('Screenings — ${widget.movie.title}')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final allShowtimes = snap.data![0] as List<ShowtimeModel>;
          final cinemas = snap.data![1] as List<CinemaModel>;
          final cinemaById = {for (final c in cinemas) c.id: c};

          final filtered = (_ignoreLocationFilter || loc == 'All Locations')
              ? allShowtimes
              : allShowtimes.where((st) => cinemaById[st.cinemaId]?.city == loc).toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF1E293B),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text('Location: ${_ignoreLocationFilter ? "All Locations" : loc}',
                          style: const TextStyle(fontSize: 13)),
                    ]),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('No screenings found in $loc.'),
                            if (allShowtimes.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() { _ignoreLocationFilter = true; }),
                                child: const Text('View screenings in other locations'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final st = filtered[i];
                          final c = cinemaById[st.cinemaId];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text('${st.cinemaName} — ${st.auditoriumName}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      Chip(label: Text('RM ${st.basePrice.toStringAsFixed(2)}')),
                                    ],
                                  ),
                                  if (c != null)
                                    Text('${c.address}, ${c.city}, ${c.state}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('🕒 ${formatMYT(st.startTime)}', style: const TextStyle(fontSize: 13)),
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
