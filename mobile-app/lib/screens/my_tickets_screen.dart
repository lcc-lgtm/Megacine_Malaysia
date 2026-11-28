import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'checkout_screen.dart';
import 'order_detail_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() { _ordersFuture = ApiClient.instance.getMyOrders(); });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED': return Colors.green;
      case 'PENDING_PAYMENT': return Colors.amber;
      case 'REFUNDED': return Colors.blueAccent;
      default: return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets & Order History'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: FutureBuilder<List<OrderModel>>(
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
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(order: o)));
                    } else {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));
                    }
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
