"""
memory_store.py
───────────────
Per-session conversation memory using LangChain's ConversationBufferMemory.

Each session is identified by a string `session_id` chosen by the client
(e.g. a Firebase UID or a UUID). Sessions are kept in-process; they reset
when the server restarts. Swap the backing store for Redis/SQL in production.
"""

from __future__ import annotations

from langchain_classic.memory import ConversationBufferMemory
from langchain_core.messages import AIMessage, HumanMessage


class MemoryStore:
    """Thread-safe (GIL-guarded) dict of session_id → ConversationBufferMemory."""

    def __init__(self) -> None:
        self._sessions: dict[str, ConversationBufferMemory] = {}

    # ── Internal ───────────────────────────────────────────────────────────────

    def _get_or_create(self, session_id: str) -> ConversationBufferMemory:
        if session_id not in self._sessions:
            self._sessions[session_id] = ConversationBufferMemory(
                return_messages=True,
                human_prefix="user",
                ai_prefix="assistant",
            )
        return self._sessions[session_id]

    # ── Public API ─────────────────────────────────────────────────────────────

    def get_history(self, session_id: str) -> list[dict[str, str]]:
        """
        Return conversation history as a list of ``{"role": ..., "content": ...}``
        dicts, ready to be passed to the OpenAI chat API.
        """
        memory = self._get_or_create(session_id)
        history: list[dict[str, str]] = []
        for msg in memory.chat_memory.messages:
            if isinstance(msg, HumanMessage):
                history.append({"role": "user", "content": msg.content})
            elif isinstance(msg, AIMessage):
                history.append({"role": "assistant", "content": str(msg.content)})
        return history

    def save_turn(self, session_id: str, user_message: str, ai_reply: str) -> None:
        """Persist a completed turn (user + assistant) into the session buffer."""
        memory = self._get_or_create(session_id)
        memory.save_context(
            {"input": user_message},
            {"output": ai_reply},
        )

    def clear(self, session_id: str) -> bool:
        """Delete session history. Returns True if the session existed."""
        if session_id in self._sessions:
            del self._sessions[session_id]
            return True
        return False

    def list_sessions(self) -> list[str]:
        return list(self._sessions.keys())

    def message_count(self, session_id: str) -> int:
        if session_id not in self._sessions:
            return 0
        return len(self._sessions[session_id].chat_memory.messages)
