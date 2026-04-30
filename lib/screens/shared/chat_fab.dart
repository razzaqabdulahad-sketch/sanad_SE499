import 'package:flutter/material.dart';
import '../employee/chat_screen.dart';

/// A small FAB that opens the employee AI chat screen.
/// Add this as [Scaffold.floatingActionButton] on any employee screen
/// (except ChatScreen itself).
class ChatFab extends StatelessWidget {
  /// Provide a unique [heroTag] when the screen already has another FAB.
  const ChatFab({super.key, this.heroTag = 'chatFab'});

  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: const Color(0xFF1A7FA0),
      foregroundColor: Colors.white,
      tooltip: 'Chat with Sanad AI',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      ),
      child: const Icon(Icons.chat_rounded),
    );
  }
}
