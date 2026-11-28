import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<OrderModel> _future;
  bool _refunding = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() { _future = ApiClient.instance.getOrderDetail(widget.orderId); });
  }

  Future<void> _requestRefund() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: const Text('Request full simulated refund? Allowed >= 60 minutes before showtime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Refund')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _refunding = true);
    try {
      await ApiClient.instance.refundOrder(widget.orderId, 'Customer requested refund via Flutter App');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order refunded & seats released!'), backgroundColor: Colors.green),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _refunding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order & E-Tickets')),
      body: FutureBuilder<OrderModel>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final order = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order No: ${order.orderNo}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Status: ${order.status}'),
                      Text('Total: RM ${order.totalAmount.toStringAsFixed(2)}'),
                      Text('Booked: ${formatMYT(order.createdAt)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (order.tickets.isNotEmpty) ...[
                const Text('E-Tickets (Scan at Gate)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...order.tickets.map((t) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(t.ticketCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Status: ${t.status}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: QrImageView(data: t.qrPayload, size: 170),
                            ),
                            const SizedBox(height: 8),
                            Text(t.qrPayload, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )),
              ],
              if (order.status == 'CONFIRMED') ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.replay),
                  label: _refunding ? const Text('Processing...') : const Text('Request Full Refund (>= 60m before)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _refunding ? null : _requestRefund,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

