import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// Base URL for the RAG chat API.
///
/// • Android emulator  → use http://10.0.2.2:8000
/// • iOS simulator     → http://142.93.1.5:8000
/// • Physical device   → replace with your machine's LAN IP (e.g. http://192.168.x.x:8000)
const String _kBaseUrl = 'http://207.154.253.127:8000';
const String _kWebhookSecret = 'Fg3BJTrpsdRDUD7QWg4-j1RMf1lMmo9L2UV5f83UqkH806HPHMB-KY-VBHlzeR26-D8ZHWUEoh5d9lEZpZGmIw';
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Firestore helpers ───────────────────────────────────────────────────

  DocumentReference _sessionDoc(String uid) =>
      _db.collection('chat_sessions').doc(uid);

  CollectionReference _messagesCol(String uid) =>
      _sessionDoc(uid).collection('messages');

  // ── Session management ──────────────────────────────────────────────────

  /// Returns the active session ID for [uid], creating one if needed.
  Future<String> getOrCreateSession(String uid) async {
    final doc = await _sessionDoc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      final existing = data?['sessionId'] as String?;
      if (existing != null && existing.isNotEmpty) return existing;
    }

    final sessionId = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    await _sessionDoc(uid).set({
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return sessionId;
  }

  /// Clears the current session and all stored messages, returning a fresh
  /// session ID.
  Future<String> clearSession(String uid) async {
    // Delete all messages
    final msgs = await _messagesCol(uid).get();
    final batch = _db.batch();
    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    // Create fresh session ID
    final sessionId = '${uid}_${DateTime.now().millisecondsSinceEpoch}';
    await _sessionDoc(uid).set({
      'sessionId': sessionId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return sessionId;
  }

  // ── Messaging ────────────────────────────────────────────────────────────

  /// Persists the user message, calls the API, persists the bot reply, and
  /// returns the bot [ChatMessage].
  Future<ChatMessage> sendMessage({
    required String uid,
    required String message,
    int topK = 5,
  }) async {
    // 1. Save user message to Firestore immediately so the UI updates fast.
    await _messagesCol(uid).add({
      'text': message,
      'isUser': true,
      'timestamp': FieldValue.serverTimestamp(),
      'sources': <Map<String, dynamic>>[],
    });

    // 2. Fetch (or create) session ID.
    final sessionId = await getOrCreateSession(uid);

    // 3. Call the RAG API.
    final response = await http
        .post(
          Uri.parse('$_kBaseUrl/chat'),
          headers: {
            'Content-Type': 'application/json',
            'X-Webhook-Secret': _kWebhookSecret,
          },
          body: jsonEncode({
            'session_id': sessionId,
            'message': message,
            'top_k': topK,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
          'API error ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = data['reply'] as String? ?? '';
    final sources = (data['sources'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatSource.fromMap)
        .toList();

    // 4. Persist bot reply.
    final docRef = await _messagesCol(uid).add({
      'text': reply,
      'isUser': false,
      'timestamp': FieldValue.serverTimestamp(),
      'sources': sources.map((s) => s.toMap()).toList(),
    });

    return ChatMessage(
      id: docRef.id,
      text: reply,
      isUser: false,
      timestamp: DateTime.now(),
      sources: sources,
    );
  }

  // ── Streaming ────────────────────────────────────────────────────────────

  /// Real-time stream of all messages for [uid], ordered oldest-first.
  Stream<List<ChatMessage>> streamMessages(String uid) {
    return _messagesCol(uid)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }
}
