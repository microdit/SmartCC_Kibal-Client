#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kibal Client Agent Wiki Vector Store v1.0
파일명: agent_wiki_vector.py
시간: 2026-10-29
내용: Layer 3 Vector DB — ChromaDB 기반 wiki 문서 의미 검색 엔진 (SmartCC_Kibal-Client 전용)
구성도:
- AgentWikiVectorStore: ChromaDB 래퍼 클래스
- Markdown 청크 분할 (헤더 기반)
- 영속적 저장 (디스크 기반 ChromaDB)
- 의미 검색 (코사인 유사도)
실행방법: python3 -c "from agent_wiki_vector import AgentWikiVectorStore; store = AgentWikiVectorStore()"
라이브러리: os, re, pathlib, chromadb

@>--> 2026-10-29
"""

import os
import re
import pathlib
import hashlib
from typing import List, Dict, Optional, Generator


def chunk_markdown(content: str, path: str = "") -> List[Dict]:
    chunks = []
    lines = content.split("\n")
    current_header = ""
    current_h2 = ""
    current_content = []
    chunk_start = 0

    def flush_chunk(end_line: int):
        if current_content:
            text = "\n".join(current_content).strip()
            if text:
                chunks.append({
                    "content": text,
                    "metadata": {
                        "path": path,
                        "h1": current_header,
                        "h2": current_h2,
                        "lines": f"{chunk_start}-{end_line}",
                        "doc_id": hashlib.md5(f"{path}:{chunk_start}:{end_line}".encode()).hexdigest()[:12],
                    }
                })

    for i, line in enumerate(lines):
        h1_match = re.match(r"^#\s+(.+)$", line)
        h2_match = re.match(r"^##\s+(.+)$", line)

        if h1_match:
            flush_chunk(i - 1)
            current_header = h1_match.group(1).strip()
            current_h2 = ""
            current_content = []
            chunk_start = i
        elif h2_match:
            flush_chunk(i - 1)
            current_h2 = h2_match.group(1).strip()
            current_content = []
            chunk_start = i
        else:
            current_content.append(line)

    flush_chunk(len(lines))
    return chunks


class AgentWikiVectorStore:
    def __init__(self, persist_dir: str = None, collection_name: str = "kibal_client_wiki"):
        if persist_dir is None:
            persist_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vector_db")
        self.persist_dir = persist_dir
        self.collection_name = collection_name
        self._client = None
        self._collection = None

    @property
    def client(self):
        if self._client is None:
            import chromadb
            self._client = chromadb.PersistentClient(path=self.persist_dir)
            print(f"[vector] Chromadb client initialized at {self.persist_dir}")
        return self._client

    @property
    def collection(self):
        if self._collection is None:
            self._collection = self.client.get_or_create_collection(
                name=self.collection_name,
                metadata={"hnsw:space": "cosine"}
            )
            print(f"[vector] Collection '{self.collection_name}' ready (count: {self._collection.count()})")
        return self._collection

    def index_file(self, file_path: str) -> int:
        path_str = str(file_path)
        rel_path = pathlib.Path(file_path).as_posix()
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception as e:
            print(f"[vector] SKIP {rel_path}: {e}")
            return 0

        chunks = chunk_markdown(content, path=rel_path)
        if not chunks:
            return 0

        existing_ids = set()
        try:
            existing = self.collection.get(where={"path": rel_path})
            if existing and existing["ids"]:
                existing_ids = set(existing["ids"])
        except Exception:
            pass

        new_chunks = [c for c in chunks if c["metadata"]["doc_id"] not in existing_ids]
        if not new_chunks:
            return 0

        ids = [c["metadata"]["doc_id"] for c in new_chunks]
        documents = [c["content"] for c in new_chunks]
        metadatas = [c["metadata"] for c in new_chunks]

        batch_size = 100
        total = 0
        for i in range(0, len(ids), batch_size):
            batch_end = min(i + batch_size, len(ids))
            self.collection.add(
                ids=ids[i:batch_end],
                documents=documents[i:batch_end],
                metadatas=metadatas[i:batch_end],
            )
            total += batch_end - i

        print(f"[vector] INDEX {rel_path}: {total} chunks added")
        return total

    def index_directory(self, root_dir: str, pattern: str = "**/*.md") -> Dict[str, int]:
        root = pathlib.Path(root_dir)
        if not root.exists():
            print(f"[vector] Directory not found: {root_dir}")
            return {}

        results = {}
        for md_file in sorted(root.glob(pattern)):
            count = self.index_file(str(md_file))
            if count > 0:
                results[str(md_file)] = count
        return results

    def search(self, query: str, n_results: int = 10) -> List[Dict]:
        if self.collection.count() == 0:
            print("[vector] Collection empty, no results")
            return []

        results = self.collection.query(
            query_texts=[query],
            n_results=n_results,
            include=["documents", "metadatas", "distances"]
        )

        output = []
        if results and results["ids"] and results["ids"][0]:
            for i, doc_id in enumerate(results["ids"][0]):
                output.append({
                    "id": doc_id,
                    "content": results["documents"][0][i][:300],
                    "path": results["metadatas"][0][i].get("path", ""),
                    "h1": results["metadatas"][0][i].get("h1", ""),
                    "h2": results["metadatas"][0][i].get("h2", ""),
                    "score": 1 - results["distances"][0][i],
                })
        return output

    def delete_document(self, path: str) -> int:
        try:
            existing = self.collection.get(where={"path": path})
            if existing and existing["ids"]:
                self.collection.delete(ids=existing["ids"])
                print(f"[vector] DELETE {path}: {len(existing['ids'])} chunks removed")
                return len(existing["ids"])
        except Exception as e:
            print(f"[vector] DELETE error {path}: {e}")
        return 0

    def reindex_file(self, file_path: str) -> int:
        self.delete_document(str(file_path))
        return self.index_file(file_path)

    def stats(self) -> Dict:
        count = self.collection.count()
        paths = set()
        try:
            all_data = self.collection.get(include=["metadatas"])
            if all_data and all_data["metadatas"]:
                paths = set(m.get("path", "") for m in all_data["metadatas"] if m.get("path"))
        except Exception:
            pass
        return {
            "total_chunks": count,
            "total_documents": len(paths),
            "documents": sorted(paths),
            "collection": self.collection_name,
            "persist_dir": self.persist_dir,
        }

    def __repr__(self):
        return f"<AgentWikiVectorStore collection={self.collection_name} chunks={self.collection.count()}>"


def demo():
    store = AgentWikiVectorStore()
    wiki_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wiki")
    if os.path.exists(wiki_dir):
        print("[vector] Indexing wiki documents...")
        store.index_directory(wiki_dir)
    print("\n[vector] Collection stats:", store.stats())
    print("\n[vector] Demo search: 'SIP 영상통화'")
    for r in store.search("SIP 영상통화"):
        safe_path = r["path"].replace("/Users/microdit/Downloads/dev/SmartCC_Kibal-Client/", "../")
        print(f"  [{r['score']:.3f}] {safe_path} | {r['h1']}")


if __name__ == "__main__":
    demo()
