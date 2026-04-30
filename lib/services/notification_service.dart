import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/user_role.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _notificationCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Future<List<String>> getUserIdsByRole(UserRole role) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: role.value)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> notifyUser({
    required String userId,
    required String title,
    required String message,
    required NotificationTopic topic,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
  }) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;

    await _notificationCollection(trimmed).add({
      'title': title.trim(),
      'message': message.trim(),
      'topic': topic.value,
      'entityId': entityId,
      'entityType': entityType,
      'metadata': metadata,
      'isRead': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> notifyUsers({
    required Iterable<String> userIds,
    required String title,
    required String message,
    required NotificationTopic topic,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
  }) async {
    final unique = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (unique.isEmpty) return;

    final now = Timestamp.fromDate(DateTime.now());
    final batch = _firestore.batch();

    for (final userId in unique) {
      final docRef = _notificationCollection(userId).doc();
      batch.set(docRef, {
        'title': title.trim(),
        'message': message.trim(),
        'topic': topic.value,
        'entityId': entityId,
        'entityType': entityType,
        'metadata': metadata,
        'isRead': false,
        'createdAt': now,
      });
    }

    await batch.commit();
  }

  Future<void> notifyUsersByRole({
    required UserRole role,
    required String title,
    required String message,
    required NotificationTopic topic,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
    String? excludeUserId,
  }) async {
    final roleUserIds = await getUserIdsByRole(role);
    final excluded = excludeUserId?.trim();

    final filtered = roleUserIds.where((uid) {
      if (excluded == null || excluded.isEmpty) return true;
      return uid != excluded;
    });

    await notifyUsers(
      userIds: filtered,
      title: title,
      message: message,
      topic: topic,
      entityId: entityId,
      entityType: entityType,
      metadata: metadata,
    );
  }

  Stream<List<AppNotification>> getMyNotificationsStream({int limit = 100}) {
    final uid = _currentUserId;
    if (uid == null) return Stream.value(const <AppNotification>[]);

    return _notificationCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<int> getUnreadCountStream() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value(0);

    return _notificationCollection(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _notificationCollection(uid).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead() async {
    final uid = _currentUserId;
    if (uid == null) return;

    final unread = await _notificationCollection(uid)
        .where('isRead', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
