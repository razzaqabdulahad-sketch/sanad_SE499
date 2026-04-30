"""
rag_engine.py
─────────────
Core RAG logic:
  • Text chunking
  • OpenAI embedding (text-embedding-3-small)
  • FAISS index (persisted to disk)
  • Similarity retrieval
  • OpenAI chat with injected context
"""

from __future__ import annotations

import json
import os
import textwrap
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import faiss
import numpy as np
from openai import OpenAI

# ── Constants ──────────────────────────────────────────────────────────────────

EMBED_MODEL = "text-embedding-3-small"
EMBED_DIM = 1536          # dimension for text-embedding-3-small
CHAT_MODEL = "gpt-4o-mini"

CHUNK_SIZE = 800          # characters per chunk
CHUNK_OVERLAP = 150       # overlap between consecutive chunks
DEFAULT_TOP_K = 5

INDEX_DIR = Path(__file__).parent / "data"
INDEX_FILE = INDEX_DIR / "faiss.index"
META_FILE = INDEX_DIR / "metadata.json"

SYSTEM_PROMPT = textwrap.dedent("""
    You are Sanad Assistant, a helpful HR policy assistant for employees.
    Answer questions clearly and concisely using ONLY the context provided below.
    If the context does not contain enough information to answer, say so and
    suggest the employee contact HR directly.
    Do not make up information.
""").strip()


# ── Data models ────────────────────────────────────────────────────────────────

@dataclass
class Document:
    text: str
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass
class RetrievedChunk:
    text: str
    metadata: dict[str, Any]
    score: float          # lower cosine distance = more relevant


# ── Helpers ────────────────────────────────────────────────────────────────────

def _chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Split *text* into overlapping chunks of at most *chunk_size* characters."""
    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunks.append(text[start:end].strip())
        start += chunk_size - overlap
    return [c for c in chunks if c]


def _normalize(vectors: np.ndarray) -> np.ndarray:
    """L2-normalise rows so inner-product == cosine similarity."""
    norms = np.linalg.norm(vectors, axis=1, keepdims=True)
    norms = np.where(norms == 0, 1.0, norms)
    return vectors / norms


# ── RAG Engine ─────────────────────────────────────────────────────────────────

class RAGEngine:
    """
    Wraps a FAISS flat index plus a parallel metadata list.

    Index is persisted to *data/* so it survives restarts.
    All mutations (`ingest`) write both files atomically after the operation.
    """

    def __init__(self) -> None:
        self._client = OpenAI()          # reads OPENAI_API_KEY from env
        self._index: faiss.IndexFlatIP   # inner-product on L2-normed vecs == cosine
        self._meta: list[dict[str, Any]] # parallel list to index rows

        INDEX_DIR.mkdir(exist_ok=True)
        self._load_or_create_index()

    # ── Persistence ────────────────────────────────────────────────────────────

    def _load_or_create_index(self) -> None:
        if INDEX_FILE.exists() and META_FILE.exists():
            self._index = faiss.read_index(str(INDEX_FILE))
            with META_FILE.open() as f:
                self._meta = json.load(f)
        else:
            self._index = faiss.IndexFlatIP(EMBED_DIM)
            self._meta = []

    def _persist(self) -> None:
        faiss.write_index(self._index, str(INDEX_FILE))
        with META_FILE.open("w") as f:
            json.dump(self._meta, f, ensure_ascii=False, indent=2)

    # ── Embedding ──────────────────────────────────────────────────────────────

    def _embed(self, texts: list[str]) -> np.ndarray:
        """Return (N, EMBED_DIM) float32 array of L2-normalised embeddings."""
        response = self._client.embeddings.create(
            model=EMBED_MODEL,
            input=texts,
        )
        vecs = np.array(
            [item.embedding for item in response.data], dtype=np.float32
        )
        return _normalize(vecs)

    # ── Public API ─────────────────────────────────────────────────────────────

    def ingest(self, documents: list[Document]) -> int:
        """
        Chunk, embed, and index *documents*.

        Returns the number of new chunks added.
        """
        chunks: list[str] = []
        chunk_meta: list[dict[str, Any]] = []

        for doc in documents:
            for i, chunk in enumerate(_chunk_text(doc.text)):
                chunks.append(chunk)
                chunk_meta.append({**doc.metadata, "chunk_index": i, "text": chunk})

        if not chunks:
            return 0

        # Embed in batches of 100 (OpenAI limit)
        batch_size = 100
        all_vecs: list[np.ndarray] = []
        for start in range(0, len(chunks), batch_size):
            batch = chunks[start : start + batch_size]
            all_vecs.append(self._embed(batch))

        vectors = np.vstack(all_vecs)
        self._index.add(vectors)
        self._meta.extend(chunk_meta)
        self._persist()
        return len(chunks)

    def retrieve(self, query: str, top_k: int = DEFAULT_TOP_K) -> list[RetrievedChunk]:
        """Return the top-*k* most relevant chunks for *query*."""
        if self._index.ntotal == 0:
            return []

        k = min(top_k, self._index.ntotal)
        q_vec = self._embed([query])                     # (1, DIM)
        scores, indices = self._index.search(q_vec, k)  # scores: cosine similarity

        results: list[RetrievedChunk] = []
        for score, idx in zip(scores[0], indices[0]):
            if idx == -1:
                continue
            meta = self._meta[idx]
            results.append(
                RetrievedChunk(
                    text=meta["text"],
                    metadata={k: v for k, v in meta.items() if k != "text"},
                    score=float(score),
                )
            )
        return results

    def chat(
        self,
        message: str,
        history: list[dict[str, str]] | None = None,
        top_k: int = DEFAULT_TOP_K,
    ) -> tuple[str, list[RetrievedChunk]]:
        """
        Retrieve relevant context, then call OpenAI chat.

        *history* is a list of ``{"role": "user"|"assistant", "content": "..."}``
        dicts representing prior turns.

        Returns ``(reply_text, retrieved_chunks)``.
        """
        history = history or []

        # 1. Retrieve context
        chunks = self.retrieve(message, top_k=top_k)

        # 2. Build context block
        if chunks:
            context_block = "\n\n---\n\n".join(
                f"[Source: {c.metadata.get('source', 'unknown')}]\n{c.text}"
                for c in chunks
            )
        else:
            context_block = "No relevant documents found in the knowledge base."

        system_content = f"{SYSTEM_PROMPT}\n\n--- CONTEXT ---\n{context_block}"

        # 3. Build messages list
        messages: list[dict[str, str]] = [{"role": "system", "content": system_content}]
        for turn in history:
            messages.append({"role": turn["role"], "content": turn["content"]})
        messages.append({"role": "user", "content": message})

        # 4. Call OpenAI chat
        response = self._client.chat.completions.create(
            model=CHAT_MODEL,
            messages=messages,       # type: ignore[arg-type]
            temperature=0.3,
            max_tokens=1024,
        )
        reply = response.choices[0].message.content or ""
        return reply, chunks

    # ── Utility ────────────────────────────────────────────────────────────────

    @property
    def total_chunks(self) -> int:
        return self._index.ntotal

    def clear(self) -> None:
        """Wipe the entire index (destructive — use carefully)."""
        self._index = faiss.IndexFlatIP(EMBED_DIM)
        self._meta = []
        self._persist()
