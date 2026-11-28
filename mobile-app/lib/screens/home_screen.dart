import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'auth_screen.dart';
import 'checkout_screen.dart';
import 'order_detail_screen.dart';
import 'showtimes_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tabIndex;
  late Future<List<MovieModel>> _moviesFuture;
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
    _refresh();
  }

  void _refresh() {
    setState(() {
      _moviesFuture = ApiClient.instance.getMovies();
      _ordersFuture = ApiClient.instance.getMyOrders();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.green;
      case 'PENDING_PAYMENT':
        return Colors.amber;
      case 'REFUNDED':
        return Colors.blueAccent;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Now Showing' : 'My Orders & E-Tickets'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              ApiClient.instance.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: _tabIndex == 0 ? _buildMoviesTab() : _buildOrdersTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) {
          setState(() => _tabIndex = idx);
          _refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.movie), label: 'Movies'),
          NavigationDestination(icon: Icon(Icons.confirmation_number), label: 'My Tickets'),
        ],
      ),
    );
  }

  Widget _buildMoviesTab() {
    return FutureBuilder<List<MovieModel>>(
      future: _moviesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final movies = snap.data ?? [];
        if (movies.isEmpty) return const Center(child: Text('No movies currently scheduled.'));

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: movies.length,
          itemBuilder: (_, i) {
            final m = movies[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: const Icon(Icons.movie_filter, color: Colors.blueAccent),
                ),
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m.durationMinutes} mins • ${m.language} • ${m.rating ?? "NR"}'),
                      if (m.synopsis != null && m.synopsis!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(m.synopsis!, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ShowtimesScreen(movie: m)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return FutureBuilder<List<OrderModel>>(
      future: _ordersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final orders = snap.data ?? [];
        if (orders.isEmpty) return const Center(child: Text('You have no bookings yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final o = orders[i];
            final seatsStr = o.items.map((e) => e.label).join(', ');
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Chip(
                      label: Text(o.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: _statusColor(o.status).withOpacity(0.22),
                      side: BorderSide(color: _statusColor(o.status)),
                    ),
                  ],
                ),
                subtitle: Text('Seats: $seatsStr  •  RM ${o.totalAmount.toStringAsFixed(2)}\n${formatMYT(o.createdAt)}'),
                isThreeLine: true,
                onTap: () async {
                  if (o.status == 'PENDING_PAYMENT') {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CheckoutScreen(order: o)),
                    );
                  } else {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)),
                    );
                  }
                  _refresh();
                },
              ),
            );
          },
        );
      },
    );
  }
}
