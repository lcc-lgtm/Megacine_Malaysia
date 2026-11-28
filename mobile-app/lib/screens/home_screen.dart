import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _pickLocation() async {
    final cities = <String>{'All Locations', ..._cinemas.map((c) => c.city).where((c) => c.isNotEmpty)}.toList();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Text(
                'CHANGE LOCATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.inkMuted,
                ),
              ),
            ),
            ...cities.map((city) {
              final isSelected = city == ApiClient.instance.selectedLocation;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.location_city_outlined,
                  color: isSelected ? AppTheme.crimson : AppTheme.inkSecondary,
                ),
                title: Text(
                  city,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.crimson : AppTheme.inkPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(context, city),
              );
            }),
          ],
        ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.crimson),
        );
      }
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
                style: TextStyle(fontSize: 12, color: AppTheme.inkSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pwdCtrl,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'New Password (8–12 chars: a-z, A-Z, 0-9, #, \$)',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Suggested: $suggested',
                      style: AppTheme.monoTabular(fontSize: 12, color: AppTheme.inkSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setDlgState(() { pwdCtrl.text = suggested; }),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              if (errMsg != null) ...[
                const SizedBox(height: 8),
                Text(errMsg!, style: const TextStyle(color: AppTheme.crimson, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final p = pwdCtrl.text;
                      if (!PasswordHelper.isValid(p)) {
                        setDlgState(() { errMsg = 'Must be 8–12 chars using only a-z, A-Z, 0-9, #, \$'; });
                        return;
                      }
                      setDlgState(() { saving = true; errMsg = null; });
                      try {
                        await ApiClient.instance.setLoginPassword(p);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password linked! Custom 24–36 char hash saved.')),
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
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Megacine Malaysia' : 'Settings'),
        actions: [
          if (_tabIndex == 0)
            TextButton.icon(
              icon: const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.crimson),
              label: Text(
                ApiClient.instance.selectedLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppTheme.inkPrimary, fontWeight: FontWeight.w600),
              ),
              onPressed: _pickLocation,
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadHomeData,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: _tabIndex == 0 ? _buildHomeTab() : _buildSettingsTab(),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.crimson,
              foregroundColor: Colors.white,
              elevation: 2,
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
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.crimson));
    }
    final bmIds = _recs?.bookmarkedMovieIds ?? {};
    final q = _searchQuery.toLowerCase();

    final filtered = _allMovies.where((m) {
      if (_bookmarkedOnly && !bmIds.contains(m.id)) return false;
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) || (m.genre ?? '').toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      color: AppTheme.crimson,
      onRefresh: _loadHomeData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search films or genres (e.g., Sci-Fi, Drama)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _searchQuery = ''; });
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() { _searchQuery = v.trim(); }),
          ),
          const SizedBox(height: 18),
          if (_recs != null && _recs!.movies.isNotEmpty && _searchQuery.isEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _recs!.preferredGenres.isEmpty
                        ? '✨ Featured For You'
                        : '🎯 Recommended (${_recs!.preferredGenres.take(2).join(", ")})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.inkPrimary),
                  ),
                ),
                FilterChip(
                  label: const Text('Bookmarked'),
                  selected: _bookmarkedOnly,
                  onSelected: (v) => setState(() { _bookmarkedOnly = v; }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recs!.movies.length,
                itemBuilder: (_, i) {
                  final m = _recs!.movies[i];
                  final isBm = bmIds.contains(m.id);
                  return GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FilmDetailScreen(movie: m, initiallyBookmarked: isBm),
                      ));
                      _loadHomeData();
                    },
                    child: Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: AppTheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                m.posterUrl != null && m.posterUrl!.isNotEmpty
                                    ? Image.network(
                                        m.posterUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Center(
                                          child: Icon(Icons.movie_creation_outlined, color: AppTheme.inkMuted, size: 36),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.movie_creation_outlined, color: AppTheme.inkMuted, size: 36),
                                      ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      isBm ? Icons.bookmark : Icons.bookmark_border,
                                      size: 16,
                                      color: isBm ? AppTheme.amber : Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${m.durationMinutes} min • ${m.language}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.tabular(
                                    const TextStyle(color: AppTheme.inkSecondary, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _bookmarkedOnly ? 'Bookmarked Films' : 'Now Showing',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.inkPrimary),
              ),
              if (!_bookmarkedOnly && _recs?.movies.isEmpty == true)
                FilterChip(
                  label: const Text('Bookmarked'),
                  selected: _bookmarkedOnly,
                  onSelected: (v) => setState(() { _bookmarkedOnly = v; }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No matching films found.', style: TextStyle(color: AppTheme.inkSecondary)),
              ),
            ),
          ...filtered.map((m) {
            final isBm = bmIds.contains(m.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                      child: Container(
                        width: 56,
                        height: 72,
                        color: AppTheme.canvasMuted,
                        child: m.posterUrl != null && m.posterUrl!.isNotEmpty
                            ? Image.network(
                                m.posterUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.movie, color: AppTheme.inkMuted),
                              )
                            : const Icon(Icons.movie, color: AppTheme.inkMuted),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${m.genre ?? "Cinema"} • ${m.durationMinutes} min • ${m.rating ?? "NR"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.tabular(
                              const TextStyle(color: AppTheme.inkSecondary, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.crimsonTint,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  m.status == 'NOW_SHOWING' ? 'Now Showing' : 'Coming Soon',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.crimson,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isBm ? 'Remove Bookmark' : 'Bookmark',
                      icon: Icon(
                        isBm ? Icons.bookmark : Icons.bookmark_border,
                        color: isBm ? AppTheme.amber : AppTheme.inkSecondary,
                      ),
                      onPressed: () => _toggleBookmark(m),
                    ),
                  ],
                ),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.crimsonTint,
                  child: Text(
                    (user?.fullName?.isNotEmpty == true ? user!.fullName![0] : (user?.email[0] ?? 'U')).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.crimson,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName?.isNotEmpty == true ? user!.fullName! : 'Megacine Member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.inkSecondary, fontSize: 13),
                      ),
                      if (user?.hasCustomHash == true) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '🔐 Custom 24–36 char Hash Active',
                          style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Username',
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.inkSecondary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => UsernameSetupScreen(email: user?.email ?? '')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.crimson),
                title: const Text('My Tickets / Order History'),
                subtitle: const Text('View QR E-Tickets & request refunds'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined, color: AppTheme.amber),
                title: const Text('AI Help & Policy Assistant'),
                subtitle: const Text('Ask about refunds, seat holds & orders'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
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
                leading: const Icon(Icons.theaters_outlined, color: AppTheme.inkPrimary),
                title: const Text('Participating Theaters'),
                subtitle: const Text('Explore Megacine locations & halls'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParticipatingTheatersScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.key_outlined, color: AppTheme.inkPrimary),
                title: const Text('Set / Update Login Password'),
                subtitle: const Text('Enable Email + Password login on this account'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
                onTap: _showSetPasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.switch_account_outlined, color: AppTheme.inkPrimary),
                title: const Text('Switch User Account'),
                subtitle: const Text('Sign in with another saved account'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
                onTap: () {
                  ApiClient.instance.logout();
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.crimson),
                title: const Text('Log Out', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.w600)),
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
