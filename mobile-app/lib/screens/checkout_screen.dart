import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
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
  String? _lastError;

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
    setState(() {
      _paying = true;
      _lastError = null;
    });
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
        final errMsg = res['message'] ?? 'Payment did not complete ($scenario)';
        setState(() => _lastError = errMsg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: AppTheme.crimson),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().replaceFirst('Exception: ', '');
      setState(() => _lastError = errStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errStr), backgroundColor: AppTheme.crimson),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final seatsText = widget.order.items.map((e) => '${e.label} (${e.seatZone})').join(', ');
    final isUnder60s = _remaining.inSeconds > 0 && _remaining.inSeconds < 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Settlement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 5-Minute Hold Countdown Banner (Monospace Tabular Zero-Jitter)
            Card(
              color: expired
                  ? AppTheme.crimsonTint
                  : (isUnder60s ? AppTheme.crimsonTint : AppTheme.amberTint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                side: BorderSide(
                  color: expired || isUnder60s ? AppTheme.crimson : AppTheme.amber,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      expired
                          ? 'SEAT HOLD EXPIRED'
                          : (isUnder60s ? '⚠️ FINAL SECONDS — COMPLETE PAYMENT NOW' : 'SEATS HELD — COMPLETE PAYMENT IN'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: expired || isUnder60s ? AppTheme.crimson : AppTheme.inkPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      expired
                          ? '00:00'
                          : '${_remaining.inMinutes.toString().padLeft(2, '0')}:${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: AppTheme.monoTabular(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: expired || isUnder60s ? AppTheme.crimson : AppTheme.inkPrimary,
                      ),
                    ),
                    if (expired) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Your seat reservation has expired. Please return to the seat map to select seats again.',
                        style: TextStyle(fontSize: 12, color: AppTheme.crimson),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error banner if last attempt failed or timed out
            if (_lastError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.crimsonTint,
                  border: Border.all(color: AppTheme.crimson, width: 1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: const TextStyle(color: AppTheme.crimson, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Entity Ticket Stub Order Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${widget.order.orderNo}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.inkPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.canvasMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.order.status,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkSecondary),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    const Text('Selected Seats:', style: TextStyle(fontSize: 12, color: AppTheme.inkSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      seatsText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.inkPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Payable:', style: TextStyle(fontSize: 14, color: AppTheme.inkSecondary)),
                        Text(
                          'MYR ${widget.order.totalAmount.toStringAsFixed(2)}',
                          style: AppTheme.tabular(
                            const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.crimson,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // UAT Simulator Gateway Console
            const Text(
              'UAT Mock Payment Gateway Console',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.inkSecondary),
            ),
            const SizedBox(height: 10),

            // Primary Succeeded Pay Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: (_paying || expired) ? null : () => _pay('SUCCEEDED'),
              child: _paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Pay MYR ${widget.order.totalAmount.toStringAsFixed(2)} (SUCCEEDED)'),
            ),
            const SizedBox(height: 12),

            // Test Scenario Simulators (FAILED / TIMEOUT)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border, width: 1),
                    ),
                    onPressed: (_paying || expired) ? null : () => _pay('FAILED'),
                    child: const Text('Simulate FAILED'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border, width: 1),
                    ),
                    onPressed: (_paying || expired) ? null : () => _pay('TIMEOUT'),
                    child: const Text('Simulate TIMEOUT'),
                  ),
                ),
              ],
            ),
            if (expired) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to Seat Map (Expired)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
