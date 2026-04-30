"""
file_parser.py
──────────────
Extracts plain text from uploaded files.
Supported formats: .txt  .pdf  .docx
"""

from __future__ import annotations

import io
from pathlib import Path
from typing import BinaryIO

import docx          # python-docx
import pypdf


SUPPORTED_EXTENSIONS = {".txt", ".pdf", ".docx"}


def _parse_txt(stream: BinaryIO) -> str:
    raw = stream.read()
    # Try UTF-8 first, fall back to latin-1
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1")


def _parse_pdf(stream: BinaryIO) -> str:
    reader = pypdf.PdfReader(stream)
    pages: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            pages.append(text)
    return "\n\n".join(pages)


def _parse_docx(stream: BinaryIO) -> str:
    doc = docx.Document(stream)
    paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
    return "\n\n".join(paragraphs)


def extract_text(filename: str, content: bytes) -> str:
    """
    Dispatch to the appropriate parser based on file extension.

    Raises ``ValueError`` for unsupported file types.
    """
    ext = Path(filename).suffix.lower()
    stream = io.BytesIO(content)

    if ext == ".txt":
        return _parse_txt(stream)
    elif ext == ".pdf":
        return _parse_pdf(stream)
    elif ext == ".docx":
        return _parse_docx(stream)
    else:
        raise ValueError(
            f"Unsupported file type '{ext}'. "
            f"Supported: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )
