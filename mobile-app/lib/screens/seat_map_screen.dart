import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.crimson),
        );
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
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.crimson,
        ),
      );
      await _loadSeats();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openAiSeatPicker() async {
    int partySize = 2;
    String selectedModel = 'gemini-3.5-flash-lite';
    const models = ['gemini-3.5-flash-lite', 'gemini-3.8-flash', 'gemini-4-hydrogen'];
    final prefCtrl = TextEditingController(text: 'Center back seats with best view');
    bool picking = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF21201E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            side: const BorderSide(color: Color(0xFF2C2B29), width: 1),
          ),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppTheme.amber, size: 20),
              SizedBox(width: 8),
              Text('AI Smart Seat Picker', style: TextStyle(color: Color(0xFFFAF9F5), fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Party Size (1–6):', style: TextStyle(color: Color(0xFFA3A09A), fontSize: 13)),
                  DropdownButton<int>(
                    value: partySize,
                    dropdownColor: const Color(0xFF21201E),
                    style: const TextStyle(color: Color(0xFFFAF9F5), fontSize: 14),
                    items: [1, 2, 3, 4, 5, 6]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n seat${n > 1 ? "s" : ""}')))
                        .toList(),
                    onChanged: picking ? null : (v) => setDlg(() { partySize = v ?? 2; }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gemini Model:', style: TextStyle(color: Color(0xFFA3A09A), fontSize: 13)),
                  DropdownButton<String>(
                    value: selectedModel,
                    dropdownColor: const Color(0xFF21201E),
                    style: const TextStyle(color: Color(0xFFFAF9F5), fontSize: 12),
                    items: models
                        .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Color(0xFFFAF9F5)))))
                        .toList(),
                    onChanged: picking ? null : (v) => setDlg(() { selectedModel = v ?? selectedModel; }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: prefCtrl,
                style: const TextStyle(color: Color(0xFFFAF9F5), fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Preference prompt',
                  labelStyle: const TextStyle(color: Color(0xFFA3A09A), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF191918),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                    borderSide: const BorderSide(color: Color(0xFF2C2B29), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                    borderSide: const BorderSide(color: AppTheme.amber, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: picking ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA3A09A))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: AppTheme.inkPrimary,
              ),
              icon: picking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.inkPrimary))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(picking ? 'AI Analyzing...' : 'Pick Best Seats'),
              onPressed: picking
                  ? null
                  : () async {
                      setDlg(() { picking = true; });
                      try {
                        final res = await ApiClient.instance.aiPickSeats(
                          widget.showtime.id,
                          partySize,
                          prefCtrl.text.trim(),
                          model: selectedModel,
                        );
                        final cfg = (res['config'] as Map<String, dynamic>?) ?? {};
                        final ids = List<String>.from(cfg['selected_seat_ids'] ?? []);
                        final modelUsed = res['model_used'] ?? selectedModel;
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {
                          _selectedIds
                            ..clear()
                            ..addAll(ids);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✨ ${res["reply"]} ($modelUsed)'),
                            backgroundColor: AppTheme.inkPrimary,
                          ),
                        );
                      } catch (e) {
                        setDlg(() { picking = false; });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.crimson),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191918),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191918),
        foregroundColor: const Color(0xFFFAF9F5),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.showtime.movieTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFFAF9F5)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.showtime.cinemaName} • ${widget.showtime.auditoriumName}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFA3A09A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppTheme.amber),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI Pick', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: (_loading || _seatMap == null) ? null : _openAiSeatPicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFAF9F5)),
            onPressed: _loadSeats,
            tooltip: 'Refresh Seats',
          ),
        ],
      ),
      body: _loading || _seatMap == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
          : Column(
              children: [
                // Micro-curve Cinema Screen Indicator
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21201E),
                    border: Border.all(color: const Color(0xFF2C2B29), width: 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 140,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'CINEMA SCREEN — FRONT STAGE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3,
                          color: Color(0xFFA3A09A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Interactive Seat Map Grid
                Expanded(
                  child: InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.7,
                    maxScale: 2.2,
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: _buildGrid(_seatMap!),
                        ),
                      ),
                    ),
                  ),
                ),
                // 5-state Legend Bar
                _buildLegend(),
                // Bottom Floating Tray
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: byRow.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    color: Color(0xFFA3A09A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              ...entry.value.map((s) {
                final selected = _selectedIds.contains(s.showtimeSeatId);
                final isAvail = s.status == 'AVAILABLE';
                final isVip = s.seatZone == 'VIP';

                Color bg = const Color(0xFF2C2B29);
                Color border = const Color(0xFF3F3E3B);
                Color textColor = const Color(0xFFA3A09A);

                if (selected) {
                  bg = AppTheme.crimson;
                  border = const Color(0xFFE05A47);
                  textColor = Colors.white;
                } else if (isAvail) {
                  bg = const Color(0xFF262523);
                  border = isVip ? AppTheme.amber : const Color(0xFF4A4845);
                  textColor = isVip ? AppTheme.amber : const Color(0xFFFAF9F5);
                } else if (s.status == 'HELD') {
                  bg = AppTheme.amber.withValues(alpha: 0.18);
                  border = AppTheme.amber.withValues(alpha: 0.6);
                  textColor = AppTheme.amber;
                } else if (s.status == 'SOLD') {
                  bg = const Color(0xFF1E1D1B);
                  border = const Color(0xFF252422);
                  textColor = const Color(0xFF55534F);
                } else if (s.status == 'BLOCKED') {
                  bg = const Color(0xFF191918);
                  border = const Color(0xFF2C2B29);
                  textColor = const Color(0xFF3F3E3B);
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
                                const SnackBar(
                                  content: Text('Maximum 6 seats per order limit reached.'),
                                  backgroundColor: AppTheme.inkPrimary,
                                ),
                              );
                            } else {
                              _selectedIds.add(s.showtimeSeatId);
                            }
                          });
                        },
                  child: Container(
                    width: 38,
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border.all(
                        color: border,
                        width: isVip && isAvail && !selected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.seatNumber}',
                      style: AppTheme.tabular(
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF21201E),
      child: const Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _LegendItem(color: Color(0xFF262523), border: Color(0xFF4A4845), label: 'Standard'),
          _LegendItem(color: Color(0xFF262523), border: AppTheme.amber, label: 'VIP Seat'),
          _LegendItem(color: AppTheme.crimson, border: Color(0xFFE05A47), label: 'Selected'),
          _LegendItem(color: Color(0xFF3B2F16), border: AppTheme.amber, label: 'Held'),
          _LegendItem(color: Color(0xFF1E1D1B), border: Color(0xFF252422), label: 'Sold'),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF21201E),
        border: Border(top: BorderSide(color: Color(0xFF2C2B29), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedIds.length} / 6 seats selected',
                    style: const TextStyle(color: Color(0xFFA3A09A), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MYR ${_totalPrice.toStringAsFixed(2)}',
                    style: AppTheme.tabular(
                      const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFAF9F5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: (_selectedIds.isEmpty || _submitting) ? null : _lockSeatsAndCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInner)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lock Seats & Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color border;
  final String label;

  const _LegendItem({required this.color, required this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Color(0xFFA3A09A), fontSize: 11)),
      ],
    );
  }
}
