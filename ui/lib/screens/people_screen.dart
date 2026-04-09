import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/gratitude_card.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _api = ApiClient();
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _api.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final users = snap.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final user = users[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.gravatarUrl),
                  ),
                  title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    user.currentStreak != null && user.currentStreak! > 0
                        ? '${user.currentStreak} day streak'
                        : 'No active streak',
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _UserGratitudesScreen(user: user)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UserGratitudesScreen extends StatefulWidget {
  final User user;
  const _UserGratitudesScreen({required this.user});

  @override
  State<_UserGratitudesScreen> createState() => _UserGratitudesScreenState();
}

class _UserGratitudesScreenState extends State<_UserGratitudesScreen> {
  final _api = ApiClient();
  late Future<List<GratitudeEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getUserGratitudes(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.displayName)),
      body: FutureBuilder<List<GratitudeEntry>>(
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
            return Center(child: Text('${widget.user.displayName} hasn\'t shared yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (ctx, i) => GratitudeCard(entry: entries[i], showUser: false),
          );
        },
      ),
    );
  }
}
