import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'checkout_screen.dart';

class SeatMapScreen extends StatefulWidget {
  final ShowtimeModel showtime;
  const SeatMapScreen({super.key, required this.showtime});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  SeatMapModel? _seatMap;
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() => _loading = true);
    try {
      final map = await ApiClient.instance.getSeatMap(widget.showtime.id);
      if (mounted) {
        setState(() {
          _seatMap = map;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalPrice {
    if (_seatMap == null) return 0;
    return _seatMap!.seats
        .where((s) => _selectedIds.contains(s.showtimeSeatId))
        .fold(0.0, (sum, s) => sum + s.price);
  }

  Future<void> _lockSeatsAndCheckout() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final order = await ApiClient.instance.createOrder(widget.showtime.id, _selectedIds.toList());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CheckoutScreen(order: order)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
      await _loadSeats();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.showtime.movieTitle} (${widget.showtime.auditoriumName})'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSeats)],
      ),
      body: _loading || _seatMap == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(14),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('SCREEN', textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildGrid(_seatMap!),
                    ),
                  ),
                ),
                _buildLegend(),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildGrid(SeatMapModel map) {
    final byRow = <String, List<ShowtimeSeatModel>>{};
    for (final s in map.seats) {
      byRow.putIfAbsent(s.rowLabel, () => []).add(s);
    }
    return Column(
      children: byRow.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text(entry.key, style: const TextStyle(color: Colors.grey))),
              ...entry.value.map((s) {
                final selected = _selectedIds.contains(s.showtimeSeatId);
                final isAvail = s.status == 'AVAILABLE';
                Color bg = Colors.grey.shade800;
                Color border = Colors.grey;
                if (selected) {
                  bg = Colors.blueAccent;
                  border = Colors.lightBlueAccent;
                } else if (isAvail) {
                  bg = Colors.green.withOpacity(0.22);
                  border = s.seatZone == 'VIP' ? Colors.purpleAccent : Colors.greenAccent;
                } else if (s.status == 'HELD') {
                  bg = Colors.amber.withOpacity(0.25);
                  border = Colors.amber;
                } else if (s.status == 'SOLD') {
                  bg = Colors.red.withOpacity(0.25);
                  border = Colors.redAccent;
                }

                return GestureDetector(
                  onTap: !isAvail
                      ? null
                      : () {
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(s.showtimeSeatId);
                            } else if (_selectedIds.length >= 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Maximum 6 seats per order.')),
                              );
                            } else {
                              _selectedIds.add(s.showtimeSeatId);
                            }
                          });
                        },
                  child: Container(
                    width: 40,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border.all(color: border, width: s.seatZone == 'VIP' ? 2 : 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        children: [
          Text('🟩 Available', style: TextStyle(fontSize: 12)),
          Text('🟦 Selected', style: TextStyle(fontSize: 12)),
          Text('🟨 Held', style: TextStyle(fontSize: 12)),
          Text('🟥 Sold', style: TextStyle(fontSize: 12)),
          Text('🟪 Border = VIP', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_selectedIds.length} / 6 seats selected', style: const TextStyle(color: Colors.grey)),
              Text('RM ${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton(
            onPressed: (_selectedIds.isEmpty || _submitting) ? null : _lockSeatsAndCheckout,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lock Seats (5m)'),
          ),
        ],
      ),
    );
  }
}
