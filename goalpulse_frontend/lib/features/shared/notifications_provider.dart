/// Real-time Firestore-backed notifications provider.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'approval', 'return', 'shared', 'checkin', 'unlock', 'general'
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: d['type'] as String? ?? 'general',
      isRead: d['isRead'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Human-readable time ago string.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Stream of the current user's 20 most recent notifications.
final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) =>
          snap.docs.map(AppNotification.fromFirestore).toList());
});

/// Count of unread notifications.
final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsStreamProvider).valueOrNull ?? [];
  return notifs.where((n) => !n.isRead).length;
});

/// Mark all notifications as read for the current user.
Future<void> markAllRead() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final snap = await FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .get();

  if (snap.docs.isEmpty) return;

  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snap.docs) {
    batch.update(doc.reference, {'isRead': true});
  }
  await batch.commit();
}
