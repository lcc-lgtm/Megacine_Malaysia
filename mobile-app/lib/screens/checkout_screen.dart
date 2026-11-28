import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final OrderModel order;
  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final exp = DateTime.tryParse(widget.order.holdExpiresAt)?.toUtc();
    if (exp == null) return;
    final diff = exp.difference(DateTime.now().toUtc());
    if (mounted) {
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pay(String scenario) async {
    setState(() => _paying = true);
    try {
      final res = await ApiClient.instance.payOrder(widget.order.id, scenario);
      if (!mounted) return;
      if (res['http_status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment succeeded! E-Tickets issued.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: widget.order.id)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Payment did not complete'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mins = _remaining.inMinutes.toString().padLeft(2, '0');
    final secs = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final expired = _remaining == Duration.zero;
    final seatsText = widget.order.items.map((e) => '${e.label} (${e.seatZone})').join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Mock Payment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: expired ? Colors.red.withOpacity(0.2) : Colors.amber.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(expired ? 'HOLD EXPIRED' : 'SEATS HELD — COMPLETE PAYMENT IN',
                        style: const TextStyle(fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text('$mins:$secs',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: expired ? Colors.redAccent : Colors.amber,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order: ${widget.order.orderNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Seats: $seatsText'),
                    const SizedBox(height: 8),
                    Text('Total Payable: RM ${widget.order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Mock Payment Adapter (Test Scenarios)', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Pay Now (SUCCEEDED)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _paying ? null : () => _pay('SUCCEEDED'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _paying ? null : () => _pay('FAILED'),
                    child: const Text('Simulate FAILED'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _paying ? null : () => _pay('TIMEOUT'),
                    child: const Text('Simulate TIMEOUT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
