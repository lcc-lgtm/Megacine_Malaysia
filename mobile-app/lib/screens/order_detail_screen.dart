import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';

class _PerforatedTicketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startY = 24.0;
    const notchRadius = 12.0;
    final leftX = 0.0;
    final rightX = size.width;
    final centerY = size.height * 0.62;

    // Draw vertical dashed line for perforation
    while (startY < size.height - 24) {
      canvas.drawLine(
        Offset(size.width * 0.72, startY),
        Offset(size.width * 0.72, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }

    // Draw side notch cutouts on the perforation line
    final cutoutPaint = Paint()
      ..color = AppTheme.canvas
      ..style = PaintingStyle.fill;

    final borderCutoutPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Left notch
    canvas.drawCircle(Offset(leftX, centerY), notchRadius, cutoutPaint);
    canvas.drawCircle(Offset(leftX, centerY), notchRadius, borderCutoutPaint);

    // Right notch
    canvas.drawCircle(Offset(rightX, centerY), notchRadius, cutoutPaint);
    canvas.drawCircle(Offset(rightX, centerY), notchRadius, borderCutoutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    setState(() {
      _future = ApiClient.instance.getOrderDetail(widget.orderId);
    });
  }

  Future<void> _requestRefund() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: const Text('Request Full Refund', style: TextStyle(color: AppTheme.inkPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to request a full refund? Seats will be released immediately. Allowed up to 60 minutes before showtime.',
          style: TextStyle(color: AppTheme.inkSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.inkSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _refunding = true);
    try {
      await ApiClient.instance.refundOrder(widget.orderId, 'Customer requested refund via Flutter App');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order successfully refunded and seats released.'),
          backgroundColor: AppTheme.inkPrimary,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _refunding = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.green.shade700;
      case 'PENDING_PAYMENT':
        return AppTheme.amber;
      case 'REFUNDED':
        return AppTheme.inkSecondary;
      default:
        return AppTheme.crimson;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order & Perforated Ticket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Order',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<OrderModel>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
                    const SizedBox(height: 12),
                    Text('Failed to load order: ${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.inkSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final order = snap.data!;
          final seatsSummary = order.items.map((e) => e.label).join(', ');
          final statusCol = _statusColor(order.status);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${order.orderNo}',
                            style: AppTheme.tabular(const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.inkPrimary)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusCol.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusCol.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            order.status,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusCol),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Seats Booked', style: TextStyle(color: AppTheme.inkSecondary, fontSize: 13)),
                        Expanded(
                          child: Text(
                            seatsSummary.isEmpty ? 'General Admission' : seatsSummary,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.inkPrimary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: AppTheme.inkSecondary, fontSize: 13)),
                        Text(
                          'MYR ${order.totalAmount.toStringAsFixed(2)}',
                          style: AppTheme.tabular(const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.crimson, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Booked At', style: TextStyle(color: AppTheme.inkSecondary, fontSize: 13)),
                        Text(
                          formatMYT(order.createdAt),
                          style: AppTheme.monoTabular(fontSize: 12, color: AppTheme.inkPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (order.status == 'PENDING_PAYMENT') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.amberTint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppTheme.amber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppTheme.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Hold active. Complete payment before expiration.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.inkPrimary),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.inkPrimary),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CheckoutScreen(order: order)),
                          ).then((_) => _reload());
                        },
                        child: const Text('Continue to Pay'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // E-Tickets Section header
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 18, color: AppTheme.crimson),
                  const SizedBox(width: 8),
                  Text(
                    'Perforated E-Tickets (${order.tickets.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.inkPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (order.tickets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text('No e-tickets generated yet for this order status.', style: TextStyle(color: AppTheme.inkSecondary)),
                )
              else
                ...order.tickets.map((t) {
                  final ticketStatusCol = t.status == 'VALID'
                      ? Colors.green.shade700
                      : t.status == 'USED'
                          ? AppTheme.inkSecondary
                          : AppTheme.crimson;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: CustomPaint(
                          painter: _PerforatedTicketPainter(),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left details column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ticketStatusCol.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t.status,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ticketStatusCol),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Megacine Malaysia',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.inkMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Ticket Code',
                                        style: TextStyle(fontSize: 11, color: AppTheme.inkSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.ticketCode,
                                        style: AppTheme.monoTabular(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.inkPrimary),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Show at Gate',
                                        style: TextStyle(fontSize: 11, color: AppTheme.inkSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Present this QR code scanner at auditorium entrance.',
                                        style: TextStyle(fontSize: 12, height: 1.3, color: AppTheme.inkSecondary),
                                      ),
                                      if (t.usedAt != null) ...[
                                        const SizedBox(height: 8),
                                        Text('Used: ${formatMYT(t.usedAt)}', style: const TextStyle(fontSize: 11, color: AppTheme.inkMuted)),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 24),

                                // Right QR code column (forced white background)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: QrImageView(
                                        data: t.qrPayload,
                                        size: 110,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Scan Verified',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.inkMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              if (order.status == 'CONFIRMED') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.crimson,
                    side: const BorderSide(color: AppTheme.crimson),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: _refunding ? const Text('Processing Refund...') : const Text('Request Full Refund (>= 60m before)'),
                  onPressed: _refunding ? null : _requestRefund,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Refunds are permitted up to 60 minutes prior to scheduled showtime start. Seats are immediately released back to inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.inkMuted, height: 1.3),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
