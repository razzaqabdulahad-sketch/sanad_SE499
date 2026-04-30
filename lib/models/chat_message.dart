import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSource {
  final String text;
  final Map<String, dynamic> metadata;
  final double score;

  const ChatSource({
    required this.text,
    required this.metadata,
    required this.score,
  });

  factory ChatSource.fromMap(Map<String, dynamic> map) {
    return ChatSource(
      text: map['text'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
          (map['metadata'] as Map<String, dynamic>?) ?? {}),
      score: (map['score'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'metadata': metadata,
        'score': score,
      };
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<ChatSource> sources;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sources = const [],
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] as String? ?? '',
      isUser: data['isUser'] as bool? ?? false,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sources: (data['sources'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatSource.fromMap)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'timestamp': Timestamp.fromDate(timestamp),
        'sources': sources.map((s) => s.toMap()).toList(),
      };
}
