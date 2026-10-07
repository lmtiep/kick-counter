#!/usr/bin/env python3
"""Adds or replaces articles in knowledge-content.json, keeping the file
formatted exactly as committed (2-space indent, UTF-8, trailing newline) and
the articles in the order of spec 2026-10-07 §3.1.

    scripts/set-knowledge-articles.py <<'JSON'
    {"safe-exercise": {"topic": "movement", "trimesters": [1, 2, 3], "reviewed": false,
                       "title": {"en": "...", "vi": "..."},
                       "summary": {"en": "...", "vi": "..."},
                       "sections": [{"heading": {"en": "...", "vi": "..."},
                                     "paragraphs": {"en": ["..."], "vi": ["..."]}}],
                       "sources": [1, 3, 5]}}
    JSON

Prints the counts the content checks use (KickCore KnowledgeChecks): the summary
(en <= 35, vi <= 45), the article (summary + headings + paragraphs, 300-500) and
the sections (2-4). The full checks run in
`scripts/test-core.sh --filter BundledKnowledgeTests`.
"""
import json
import os
import sys

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Packages", "KickCore",
                    "Sources", "KickCore", "Resources", "knowledge-content.json")
# Spec §3.1, in file order: id -> (topic, trimesters).
CATALOGUE = {
    "nutrition-first-trimester": ("nutrition", [1]),
    "food-safety": ("nutrition", [1, 2, 3]),
    "iron-calcium-balanced-meals": ("nutrition", [2, 3]),
    "safe-exercise": ("movement", [1, 2, 3]),
    "gentle-exercise-second-trimester": ("movement", [2]),
    "pelvic-floor-posture": ("movement", [2, 3]),
    "first-trimester-tiredness": ("sleep", [1]),
    "sleep-positions": ("sleep", [2, 3]),
    "sleeping-well-late-pregnancy": ("sleep", [3]),
    "early-pregnancy-worries": ("feelings", [1]),
    "changing-body-feelings": ("feelings", [2]),
    "preparing-for-motherhood": ("feelings", [3]),
    "antenatal-checkup-milestones": ("checkups", [1, 2, 3]),
    "first-trimester-screening": ("checkups", [1]),
    "anomaly-scan-glucose-test": ("checkups", [2]),
    "signs-of-labour": ("birth", [3]),
    "hospital-bag": ("birth", [3]),
    "birth-plan-breastfeeding": ("birth", [3]),
}
KEYS = ["topic", "trimesters", "reviewed", "title", "summary", "sections", "sources"]
LANGUAGES = ["en", "vi"]


def words(text):
    return len(text.split())


def text_pair(article_id, name, value):
    if not isinstance(value, dict) or sorted(value) != LANGUAGES or \
            not all(isinstance(value[l], str) and value[l].strip() for l in LANGUAGES):
        sys.exit(f"{article_id}: {name} needs non-empty en and vi strings")


def check(article_id, article, source_count):
    if article_id not in CATALOGUE:
        sys.exit(f"unknown article id: {article_id}")
    if list(article) != KEYS:
        sys.exit(f"{article_id}: keys must be {KEYS}, in this order")
    topic, trimesters = CATALOGUE[article_id]
    if article["topic"] != topic or article["trimesters"] != trimesters:
        sys.exit(f"{article_id}: topic must be {topic!r} and trimesters {trimesters}")
    if article["reviewed"] is not False:
        sys.exit(f"{article_id}: reviewed must be false (only the doctor's sign-off changes it)")
    text_pair(article_id, "title", article["title"])
    text_pair(article_id, "summary", article["summary"])
    sections = article["sections"]
    if not isinstance(sections, list) or not sections:
        sys.exit(f"{article_id}: sections must be a non-empty list")
    for number, section in enumerate(sections, start=1):
        if list(section) != ["heading", "paragraphs"]:
            sys.exit(f"{article_id}: section {number} keys must be ['heading', 'paragraphs']")
        text_pair(article_id, f"section {number} heading", section["heading"])
        paragraphs = section["paragraphs"]
        if sorted(paragraphs) != LANGUAGES:
            sys.exit(f"{article_id}: section {number} paragraphs need exactly en and vi")
        for l in LANGUAGES:
            if not paragraphs[l] or not all(isinstance(p, str) and p.strip() for p in paragraphs[l]):
                sys.exit(f"{article_id}: section {number} paragraphs.{l} need non-empty strings")
    sources = article["sources"]
    if not sources or not all(isinstance(i, int) and 0 <= i < source_count for i in sources):
        sys.exit(f"{article_id}: sources must be indices 0..{source_count - 1}")


def main():
    articles = json.load(sys.stdin)
    with open(PATH, encoding="utf-8") as f:
        content = json.load(f)
    by_id = {a["id"]: a for a in content["articles"]}
    for article_id, article in articles.items():
        check(article_id, article, len(content["sources"]))
        by_id[article_id] = {"id": article_id, **article}
        for l in LANGUAGES:
            summary = words(article["summary"][l])
            total = summary + sum(words(s["heading"][l]) + sum(words(p) for p in s["paragraphs"][l])
                                  for s in article["sections"])
            print(f"{article_id} {l}: summary {summary}, words {total}, sections {len(article['sections'])}")
    order = list(CATALOGUE)
    content["articles"] = sorted(by_id.values(), key=lambda a: order.index(a["id"]))
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
