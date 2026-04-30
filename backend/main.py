"""
main.py
───────
FastAPI RAG service for Sanad HR Assistant.

Endpoints
─────────
POST /ingest                          — upload files (txt, pdf, docx) to the knowledge base
POST /chat                            — RAG chat; history managed server-side per session
GET  /health                          — liveness check
DELETE /index                         — clear the entire vector index (admin)
DELETE /sessions/{session_id}         — wipe a session's conversation history
GET    /sessions/{session_id}/history — retrieve a session's conversation history
"""

from __future__ import annotations

import hmac
import os
from contextlib import asynccontextmanager
from typing import Annotated, Any

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, HTTPException, Header, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv()

from file_parser import extract_text        # noqa: E402
from memory_store import MemoryStore        # noqa: E402
from rag_engine import Document, RAGEngine  # noqa: E402

WEBHOOK_SECRET_ENV = "WEBHOOK_SECRET"
WEBHOOK_SECRET_HEADER = "X-Webhook-Secret"


def verify_webhook_secret(
    x_webhook_secret: Annotated[str | None, Header(alias=WEBHOOK_SECRET_HEADER)] = None,
) -> None:
    """Authorize requests using a shared webhook secret header."""
    expected_secret = os.getenv(WEBHOOK_SECRET_ENV)
    if not expected_secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"{WEBHOOK_SECRET_ENV} is not configured on the server.",
        )
    if x_webhook_secret is None or not hmac.compare_digest(x_webhook_secret, expected_secret):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid webhook secret.")

# ── Lifespan: initialise the engine once at startup ───────────────────────────

engine: RAGEngine | None = None
memory: MemoryStore | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):                   # noqa: D401
    global engine, memory
    engine = RAGEngine()
    memory = MemoryStore()
    yield
    # nothing to clean up


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Sanad RAG Service",
    description="Retrieval-Augmented Generation backend for Sanad HR Assistant.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Schemas ───────────────────────────────────────────────────────────────────

class IngestResponse(BaseModel):
    files_processed: int
    chunks_added: int
    total_chunks: int


class ChatRequest(BaseModel):
    session_id: str = Field(..., description="Unique session identifier (e.g. user UID or UUID).")
    message: str = Field(..., description="The user's latest message.")
    top_k: int = Field(5, ge=1, le=20, description="Number of context chunks to retrieve.")


class SourceChunk(BaseModel):
    text: str
    metadata: dict[str, Any]
    score: float


class ChatResponse(BaseModel):
    reply: str
    session_id: str
    sources: list[SourceChunk]


class HistoryTurn(BaseModel):
    role: str
    content: str


class SessionHistoryResponse(BaseModel):
    session_id: str
    turns: list[HistoryTurn]


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health", tags=["meta"], dependencies=[Depends(verify_webhook_secret)])
def health() -> dict[str, Any]:
    """Liveness check. Returns index size and active session count."""
    return {
        "status": "ok",
        "total_chunks": engine.total_chunks if engine else 0,
        "active_sessions": len(memory.list_sessions()) if memory else 0,
    }


@app.post(
    "/ingest",
    response_model=IngestResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["knowledge base"],
    dependencies=[Depends(verify_webhook_secret)],
)
async def ingest(
    file: UploadFile = File(..., description=".txt, .pdf, or .docx file")
) -> IngestResponse:
    """
    Upload a file. It will be parsed, split into chunks, embedded,
    and stored in the FAISS index.
    """

    if engine is None:
        raise HTTPException(status_code=503, detail="Engine not initialised.")

    try:
        content = await file.read()
        text = extract_text(file.filename, content)

        if not text.strip():
            raise HTTPException(status_code=422, detail="File contains no text.")

        doc = Document(
            text=text,
            metadata={"source": file.filename, "size_bytes": len(content)},
        )

        added = engine.ingest([doc])

    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    return IngestResponse(
        files_processed=1,
        chunks_added=added,
        total_chunks=engine.total_chunks,
    )

@app.post(
    "/chat",
    response_model=ChatResponse,
    tags=["chat"],
    summary="RAG-powered chat with server-side session memory",
    dependencies=[Depends(verify_webhook_secret)],
)
def chat(request: ChatRequest) -> ChatResponse:
    """
    Retrieve the most relevant knowledge-base chunks for *message*, generate a
    grounded reply using OpenAI chat, and persist the conversation turn to the
    server-side session buffer (LangChain `ConversationBufferMemory`).

    The client only needs to supply a stable `session_id` — history is managed
    automatically server-side.
    """
    if engine is None or memory is None:
        raise HTTPException(status_code=503, detail="Engine not initialised.")

    history = memory.get_history(request.session_id)

    try:
        reply, chunks = engine.chat(
            message=request.message,
            history=history,
            top_k=request.top_k,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    memory.save_turn(request.session_id, request.message, reply)

    return ChatResponse(
        reply=reply,
        session_id=request.session_id,
        sources=[
            SourceChunk(text=c.text, metadata=c.metadata, score=c.score)
            for c in chunks
        ],
    )


@app.get(
    "/sessions/{session_id}/history",
    response_model=SessionHistoryResponse,
    tags=["sessions"],
    summary="Retrieve conversation history for a session",
    dependencies=[Depends(verify_webhook_secret)],
)
def get_session_history(session_id: str) -> SessionHistoryResponse:
    """Return all turns stored in the session's conversation buffer."""
    if memory is None:
        raise HTTPException(status_code=503, detail="Engine not initialised.")
    turns = [
        HistoryTurn(role=t["role"], content=t["content"])
        for t in memory.get_history(session_id)
    ]
    return SessionHistoryResponse(session_id=session_id, turns=turns)


@app.delete(
    "/sessions/{session_id}",
    tags=["sessions"],
    summary="Clear a session's conversation history",
    dependencies=[Depends(verify_webhook_secret)],
)
def clear_session(session_id: str) -> dict[str, str]:
    """Wipe the LangChain memory buffer for the given session."""
    if memory is None:
        raise HTTPException(status_code=503, detail="Engine not initialised.")
    found = memory.clear(session_id)
    if not found:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found.")
    return {"status": "cleared", "session_id": session_id}


@app.delete(
    "/index",
    tags=["knowledge base"],
    summary="Clear the entire vector index (destructive)",
    dependencies=[Depends(verify_webhook_secret)],
)
def clear_index() -> dict[str, str]:
    """Wipe all vectors and metadata from the FAISS index. Use with care."""
    if engine is None:
        raise HTTPException(status_code=503, detail="Engine not initialised.")
    engine.clear()
    return {"status": "index cleared"}
