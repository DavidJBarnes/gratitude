import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/gratitude_card.dart';
import '../widgets/streak_banner.dart';
import 'create_gratitude_screen.dart';
import 'people_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        key: ValueKey(_refreshKey),
        index: _currentIndex,
        children: const [
          _FeedTab(),
          _MyGratitudesTab(),
          PeopleScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Mine'),
          NavigationDestination(icon: Icon(Icons.people), label: 'People'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateGratitudeScreen()),
          );
          if (created == true) setState(() => _refreshKey++);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _api = ApiClient();
  late Future<List<GratitudeEntry>> _feedFuture;
  late Future<Streak> _streakFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _feedFuture = _api.getFeed();
    _streakFuture = _api.getMyStreak();
  }

  @override
  void didUpdateWidget(covariant _FeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gratitude'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _api.clearToken();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _refresh()),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<Streak>(
              future: _streakFuture,
              builder: (ctx, snap) {
                if (snap.hasData) return StreakBanner(streak: snap.data!);
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<GratitudeEntry>>(
              future: _feedFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No gratitude entries yet. Be the first!'),
                    ),
                  );
                }
                return Column(
                  children: entries.map((e) => GratitudeCard(entry: e, showUser: true)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MyGratitudesTab extends StatefulWidget {
  const _MyGratitudesTab();

  @override
  State<_MyGratitudesTab> createState() => _MyGratitudesTabState();
}

class _MyGratitudesTabState extends State<_MyGratitudesTab> {
  final _api = ApiClient();
  late Future<List<GratitudeEntry>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _api.getMyGratitudes();
  }

  @override
  void didUpdateWidget(covariant _MyGratitudesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Gratitude')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _refresh()),
        child: FutureBuilder<List<GratitudeEntry>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final entries = snap.data ?? [];
            if (entries.isEmpty) {
              return const Center(child: Text('Start expressing gratitude!'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (ctx, i) => GratitudeCard(
                entry: entries[i],
                showUser: false,
                onDelete: () async {
                  await _api.deleteGratitude(entries[i].id);
                  setState(() => _refresh());
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
