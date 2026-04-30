import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationTopic {
  complaint,
  leave,
  contract,
  general;

  String get value => name;

  String get displayName {
    switch (this) {
      case NotificationTopic.complaint:
        return 'Complaint';
      case NotificationTopic.leave:
        return 'Leave';
      case NotificationTopic.contract:
        return 'Contract';
      case NotificationTopic.general:
        return 'General';
    }
  }

  static NotificationTopic fromString(String raw) {
    return NotificationTopic.values.firstWhere(
      (topic) => topic.name == raw,
      orElse: () => NotificationTopic.general,
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationTopic topic;
  final String? entityId;
  final String? entityType;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.topic,
    this.entityId,
    this.entityType,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      topic: NotificationTopic.fromString((map['topic'] ?? 'general').toString()),
      entityId: map['entityId']?.toString(),
      entityType: map['entityType']?.toString(),
      metadata: map['metadata'] is Map<String, dynamic>
          ? map['metadata'] as Map<String, dynamic>
          : map['metadata'] is Map
          ? (map['metadata'] as Map)
            .map((key, value) => MapEntry('$key', value))
          : null,
      isRead: map['isRead'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'topic': topic.value,
      'entityId': entityId,
      'entityType': entityType,
      'metadata': metadata,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
