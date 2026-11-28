import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../utils/password_helper.dart';
import 'ai_assistant_screen.dart';
import 'auth_screen.dart';
import 'film_detail_screen.dart';
import 'my_tickets_screen.dart';
import 'participating_theaters_screen.dart';
import 'username_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tabIndex;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _bookmarkedOnly = false;
  bool _loading = true;

  List<MovieModel> _allMovies = [];
  RecommendationsModel? _recs;
  List<CinemaModel> _cinemas = [];

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() { _loading = true; });
    try {
      await ApiClient.instance.initPrefs();
      final results = await Future.wait([
        ApiClient.instance.getMovies(),
        ApiClient.instance.getRecommendations(),
        ApiClient.instance.getCinemas(),
      ]);
      if (mounted) {
        setState(() {
          _allMovies = results[0] as List<MovieModel>;
          _recs = results[1] as RecommendationsModel;
          _cinemas = results[2] as List<CinemaModel>;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _pickLocation() async {
    final cities = <String>{'All Locations', ..._cinemas.map((c) => c.city).where((c) => c.isNotEmpty)}.toList();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Change Location', style: TextStyle(fontWeight: FontWeight.bold))),
          ...cities.map((city) => ListTile(
                leading: Icon(city == ApiClient.instance.selectedLocation ? Icons.check_circle : Icons.location_city,
                    color: Colors.blueAccent),
                title: Text(city),
                onTap: () => Navigator.pop(context, city),
              )),
        ],
      ),
    );
    if (chosen != null) {
      await ApiClient.instance.saveLocation(chosen);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleBookmark(MovieModel m) async {
    final isBm = _recs?.bookmarkedMovieIds.contains(m.id) ?? false;
    try {
      await ApiClient.instance.toggleBookmark(m.id, isBm);
      final updated = await ApiClient.instance.getRecommendations();
      if (mounted) setState(() { _recs = updated; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showSetPasswordDialog() async {
    final pwdCtrl = TextEditingController();
    String suggested = PasswordHelper.generateRandom12();
    bool saving = false;
    String? errMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Set / Update Login Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link a password to your account so you can sign in with either Google or Email + Password using the same profile.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwdCtrl,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'New Password (8?12 chars: a-z, A-Z, 0-9, #, \$)',
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  Expanded(child: Text('Suggested: $suggested', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                  TextButton(
                    onPressed: () => setDlgState(() { pwdCtrl.text = suggested; }),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              if (errMsg != null)
                Text(errMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final p = pwdCtrl.text;
                      if (!PasswordHelper.isValid(p)) {
                        setDlgState(() { errMsg = 'Must be 8?12 chars using only a-z, A-Z, 0-9, #, \$'; });
                        return;
                      }
                      setDlgState(() { saving = true; errMsg = null; });
                      try {
                        await ApiClient.instance.setLoginPassword(p);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password linked! Custom 24?36 char hash saved.'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() {
                          saving = false;
                          errMsg = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Megacine Home' : 'Settings'),
        actions: [
          if (_tabIndex == 0)
            TextButton.icon(
              icon: const Icon(Icons.location_on, size: 18),
              label: Text(ApiClient.instance.selectedLocation),
              onPressed: _pickLocation,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHomeData),
        ],
      ),
      body: _tabIndex == 0 ? _buildHomeTab() : _buildSettingsTab(),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI Concierge'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiAssistantScreen(
                    allMovies: _allMovies,
                    bookmarkedIds: _recs?.bookmarkedMovieIds ?? {},
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() { _tabIndex = idx; }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final bmIds = _recs?.bookmarkedMovieIds ?? {};
    final q = _searchQuery.toLowerCase();

    final filtered = _allMovies.where((m) {
      if (_bookmarkedOnly && !bmIds.contains(m.id)) return false;
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) || (m.genre ?? '').toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadHomeData,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search films or genres (e.g., Sci-Fi, Action)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _searchQuery = ''; });
                    })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() { _searchQuery = v.trim(); }),
          ),
          const SizedBox(height: 12),
          if (_recs != null && _recs!.movies.isNotEmpty && _searchQuery.isEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _recs!.preferredGenres.isEmpty ? '✨ Featured For You' : '🎯 Recommended (${_recs!.preferredGenres.take(2).join(", ")})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                FilterChip(
                  label: const Text('Bookmarked'),
                  selected: _bookmarkedOnly,
                  onSelected: (v) => setState(() { _bookmarkedOnly = v; }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recs!.movies.length,
                itemBuilder: (_, i) {
                  final m = _recs!.movies[i];
                  return GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FilmDetailScreen(movie: m, initiallyBookmarked: bmIds.contains(m.id)),
                      ));
                      _loadHomeData();
                    },
                    child: Container(
                      width: 190,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(m.genre ?? 'Featured', style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                              ),
                              Icon(bmIds.contains(m.id) ? Icons.bookmark : Icons.bookmark_border,
                                  size: 18, color: bmIds.contains(m.id) ? Colors.amber : Colors.grey),
                            ],
                          ),
                          const Spacer(),
                          Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${m.durationMinutes}m • ${m.language}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(_bookmarkedOnly ? 'Bookmarked Films' : 'Now Showing',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No matching films found.'))),
          ...filtered.map((m) {
            final isBm = bmIds.contains(m.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: const Icon(Icons.movie_filter, color: Colors.blueAccent),
                ),
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${m.genre ?? "Cinema"} • ${m.durationMinutes}m • ${m.rating ?? "NR"}'),
                trailing: IconButton(
                  icon: Icon(isBm ? Icons.bookmark : Icons.bookmark_border, color: isBm ? Colors.amber : null),
                  onPressed: () => _toggleBookmark(m),
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FilmDetailScreen(movie: m, initiallyBookmarked: isBm),
                  ));
                  _loadHomeData();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final user = ApiClient.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blueAccent,
              child: Text((user?.fullName?.isNotEmpty == true ? user!.fullName![0] : (user?.email[0] ?? 'U')).toUpperCase(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            title: Text(user?.fullName?.isNotEmpty == true ? user!.fullName! : 'Megacine Member',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.email ?? ''),
                if (user?.hasCustomHash == true)
                  const Text('🔐 Custom 24–36 char Hash Active', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Username',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UsernameSetupScreen(email: user?.email ?? '')),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.confirmation_number, color: Colors.blueAccent),
                title: const Text('My Tickets / Order History'),
                subtitle: const Text('View QR E-Tickets & request refunds'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
                title: const Text('AI Help & Policy Assistant'),
                subtitle: const Text('Ask about refunds, seat holds & your orders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiAssistantScreen(
                      allMovies: _allMovies,
                      bookmarkedIds: _recs?.bookmarkedMovieIds ?? {},
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.theaters, color: Colors.amber),
                title: const Text('Participating Theaters'),
                subtitle: const Text('Explore Megacine locations & halls'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParticipatingTheatersScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.key, color: Colors.purpleAccent),
                title: const Text('Set / Update Login Password'),
                subtitle: const Text('Enable Email + Password login on this same account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSetPasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.switch_account, color: Colors.tealAccent),
                title: const Text('Switch User Account'),
                subtitle: const Text('Sign in with another saved account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ApiClient.instance.logout();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  ApiClient.instance.logout();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
