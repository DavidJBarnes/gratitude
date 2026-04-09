class User {
  final String id;
  final String email;
  final String displayName;
  final String gravatarUrl;
  final DateTime createdAt;
  final int? currentStreak;
  final int? longestStreak;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.gravatarUrl,
    required this.createdAt,
    this.currentStreak,
    this.longestStreak,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      displayName: json['display_name'],
      gravatarUrl: json['gravatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      currentStreak: json['current_streak'],
      longestStreak: json['longest_streak'],
    );
  }
}

class GratitudeEntry {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? user;

  GratitudeEntry({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory GratitudeEntry.fromJson(Map<String, dynamic> json) {
    return GratitudeEntry(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      entryDate: DateTime.parse(json['entry_date']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

class Streak {
  final int currentStreak;
  final int longestStreak;
  final int totalEntries;
  final String streakLabel;

  Streak({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalEntries,
    required this.streakLabel,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      currentStreak: json['current_streak'],
      longestStreak: json['longest_streak'],
      totalEntries: json['total_entries'],
      streakLabel: json['streak_label'],
    );
  }
}
