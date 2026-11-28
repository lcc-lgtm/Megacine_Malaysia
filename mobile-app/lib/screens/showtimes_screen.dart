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
  late Future<List<ShowtimeModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.getShowtimes(widget.movie.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.movie.title)),
      body: FutureBuilder<List<ShowtimeModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No available showtimes for this movie yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final st = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('${st.cinemaName} — ${st.auditoriumName}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${formatMYT(st.startTime)}\nFrom RM ${st.basePrice.toStringAsFixed(2)}'),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SeatMapScreen(showtime: st)),
                    ),
                    child: const Text('Select Seats'),
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
