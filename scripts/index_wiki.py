#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kibal Client Wiki Indexer v1.0
파일명: scripts/index_wiki.py
시간: 2026-10-29
내용: wiki 디렉토리 전체를 ChromaDB Vector Store에 인덱싱 (SmartCC_Kibal-Client 전용)
실행방법: python3 scripts/index_wiki.py [--reindex] [--search "질문"]

@>--> 2026-10-29
"""

import os
import sys
import argparse

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from agent_wiki_vector import AgentWikiVectorStore


def main():
    parser = argparse.ArgumentParser(description="Kibal Client Wiki Vector DB Indexer")
    parser.add_argument("--reindex", action="store_true", help="전체 재인덱싱")
    parser.add_argument("--search", type=str, default=None, help="의미 검색 실행")
    parser.add_argument("--n", type=int, default=10, help="검색 결과 수")
    parser.add_argument("--stats", action="store_true", help="통계만 출력")
    args = parser.parse_args()

    store = AgentWikiVectorStore()
    wiki_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "wiki")

    if args.reindex:
        print("[index] Full reindex...")
        import shutil
        if os.path.exists(store.persist_dir):
            shutil.rmtree(store.persist_dir)
            print(f"[index] Cleared {store.persist_dir}")

    if not os.path.exists(wiki_dir):
        print(f"[index] Wiki directory not found: {wiki_dir}")
        sys.exit(1)

    results = store.index_directory(wiki_dir)
    total = sum(results.values())
    print(f"\n[index] Done: {len(results)} files, {total} chunks indexed")

    if args.stats:
        stats = store.stats()
        print(f"\n[index] Stats: {stats['total_chunks']} chunks from {stats['total_documents']} documents")

    if args.search:
        print(f"\n[index] Search: '{args.search}'")
        for r in store.search(args.search, n_results=args.n):
            print(f"  [{r['score']:.3f}] {r['path']}")
            print(f"       {r['h1']} > {r['h2']}")
            snippet = r['content'][:150].replace("\n", " ")
            print(f"       {snippet}...\n")


if __name__ == "__main__":
    main()
