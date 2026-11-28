import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';
import 'order_detail_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  String _filterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _ordersFuture = ApiClient.instance.getMyOrders();
    });
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
        title: const Text('My Tickets & Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.canvasMuted,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Orders'),
                  const SizedBox(width: 8),
                  _buildFilterChip('CONFIRMED', 'Confirmed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PENDING_PAYMENT', 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('REFUNDED', 'Refunded'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.crimson,
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<OrderModel>>(
                future: _ordersFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 60),
                        const Center(child: Icon(Icons.error_outline, size: 48, color: AppTheme.crimson)),
                        const SizedBox(height: 16),
                        Text('Failed to load orders: ${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.inkSecondary)),
                        const SizedBox(height: 16),
                        Center(child: ElevatedButton(onPressed: _reload, child: const Text('Retry'))),
                      ],
                    );
                  }

                  final allOrders = snap.data ?? [];
                  final orders = _filterStatus == 'ALL'
                      ? allOrders
                      : allOrders.where((o) => o.status == _filterStatus).toList();

                  if (orders.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(40),
                      children: [
                        const SizedBox(height: 80),
                        const Center(child: Icon(Icons.confirmation_number_outlined, size: 56, color: AppTheme.inkMuted)),
                        const SizedBox(height: 16),
                        const Text(
                          'No orders found in this category.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.inkPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your booked tickets and reservation history will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.inkSecondary),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final o = orders[i];
                      final seatsStr = o.items.map((e) => e.label).join(', ');
                      final statusCol = _statusColor(o.status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
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
                            _reload();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
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
                                        'Order #${o.orderNo}',
                                        style: AppTheme.tabular(const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.inkPrimary)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusCol.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusCol.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        o.status,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusCol),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Seats: ${seatsStr.isEmpty ? "General Admission" : seatsStr}',
                                        style: const TextStyle(fontSize: 13, color: AppTheme.inkSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      'MYR ${o.totalAmount.toStringAsFixed(2)}',
                                      style: AppTheme.tabular(const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.crimson, fontSize: 14)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatMYT(o.createdAt),
                                      style: AppTheme.monoTabular(fontSize: 11, color: AppTheme.inkMuted),
                                    ),
                                    const Row(
                                      children: [
                                        Text('View Ticket', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.crimson)),
                                        SizedBox(width: 4),
                                        Icon(Icons.chevron_right, size: 16, color: AppTheme.crimson),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filterStatus == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      selected: selected,
      selectedColor: AppTheme.crimsonTint,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(color: selected ? AppTheme.crimson : AppTheme.inkSecondary),
      side: BorderSide(color: selected ? AppTheme.crimson : AppTheme.border),
      onSelected: (_) => setState(() => _filterStatus = key),
    );
  }
}
