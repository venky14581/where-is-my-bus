/// One entry in the student's alerts list: a server alert about their
/// route's trip, or a transport office announcement.
sealed class FeedItem {
  const FeedItem({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

enum TripAlertKind { tripStarted, delay, late, breakdown }

/// From `alerts/{id}`, written by Cloud Functions.
final class TripAlert extends FeedItem {
  const TripAlert({
    required super.id,
    required super.createdAt,
    required this.kind,
    this.busNumber = '',
    this.minutes,
  });

  final TripAlertKind kind;
  final String busNumber;

  /// How late, for [TripAlertKind.delay].
  final int? minutes;

  static TripAlert? tryFromMap(String id, Map<String, dynamic> data, DateTime? createdAt) {
    final kind = TripAlertKind.values.where((k) => k.name == data['kind']).firstOrNull;
    if (kind == null || createdAt == null) return null;
    final params = data['params'] is Map ? data['params'] as Map : const {};
    return TripAlert(
      id: id,
      createdAt: createdAt,
      kind: kind,
      busNumber: params['busNumber'] as String? ?? '',
      minutes: (params['minutes'] as num?)?.toInt(),
    );
  }
}

/// From `announcements/{id}`, posted by the transport office.
final class Announcement extends FeedItem {
  const Announcement({required super.id, required super.createdAt, required this.title, required this.body});

  final String title;
  final String body;
}
