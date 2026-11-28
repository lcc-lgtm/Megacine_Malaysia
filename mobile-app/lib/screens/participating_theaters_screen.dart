import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class ParticipatingTheatersScreen extends StatelessWidget {
  const ParticipatingTheatersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Participating Theaters')),
      body: FutureBuilder<List<CinemaModel>>(
        future: ApiClient.instance.getCinemas(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final cinemas = snap.data ?? [];
          if (cinemas.isEmpty) return const Center(child: Text('No participating theaters found.'));
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: cinemas.length,
            itemBuilder: (_, i) {
              final c = cinemas[i];
              final halls = c.auditoriums.map((a) => '${a.name} (${a.totalRows}×${a.totalCols})').join(' • ');
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: const CircleAvatar(child: Icon(Icons.theaters)),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.address}, ${c.city}, ${c.state}'),
                        const SizedBox(height: 4),
                        Text('Halls: ${halls.isEmpty ? "Coming soon" : halls}',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ],
                    ),
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
