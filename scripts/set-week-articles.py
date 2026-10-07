#!/usr/bin/env python3
"""Sets the `article` of weeks in pregnancy-content.json, keeping the file
formatted exactly as committed (2-space indent, UTF-8, trailing newline).

    scripts/set-week-articles.py <<'JSON'
    {"24": {"lead": {"en": "...", "vi": "..."},
            "sizeNote": {"en": ["..."], "vi": ["..."]},
            "development": {"en": ["...", "..."], "vi": ["...", "..."]},
            "body": {"en": ["..."], "vi": ["..."]},
            "todo": {"en": ["..."], "vi": ["..."]},
            "sources": [1, 2, 4]}}
    JSON

Replaces an existing article of the same week. Prints the word counts the
content checks use (KickCore WeekArticleChecks): the lead (en <= 30, vi <= 40)
and each tab (150-300): baby = lead + sizeNote + development, mom = body + todo.
The full checks run in `scripts/test-core.sh --filter BundledArticleTests`.
"""
import json
import os
import sys

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Packages", "KickCore",
                    "Sources", "KickCore", "Resources", "pregnancy-content.json")
PARAGRAPH_FIELDS = ["sizeNote", "development", "body", "todo"]
KEYS = ["lead"] + PARAGRAPH_FIELDS + ["sources"]
LANGUAGES = ["en", "vi"]


def words(text):
    return len(text.split())


def check(week, article, source_count):
    if list(article) != KEYS:
        sys.exit(f"week {week}: keys must be {KEYS}, in this order")
    lead = article["lead"]
    if sorted(lead) != LANGUAGES or not all(isinstance(lead[l], str) and lead[l].strip() for l in LANGUAGES):
        sys.exit(f"week {week}: lead needs non-empty en and vi strings")
    for field in PARAGRAPH_FIELDS:
        value = article[field]
        if sorted(value) != LANGUAGES:
            sys.exit(f"week {week}: {field} needs exactly en and vi")
        for l in LANGUAGES:
            paragraphs = value[l]
            if not paragraphs or not all(isinstance(p, str) and p.strip() for p in paragraphs):
                sys.exit(f"week {week}: {field}.{l} needs non-empty paragraphs")
    sources = article["sources"]
    if not sources or not all(isinstance(i, int) and 0 <= i < source_count for i in sources):
        sys.exit(f"week {week}: sources must be indices 0..{source_count - 1}")


def main():
    articles = json.load(sys.stdin)
    with open(PATH, encoding="utf-8") as f:
        content = json.load(f)
    weeks = {w["week"]: w for w in content["weeks"]}
    for key, article in articles.items():
        week = int(key)
        if week not in weeks:
            sys.exit(f"unknown week: {key}")
        check(week, article, len(content["sources"]))
        weeks[week]["article"] = article
        for l in LANGUAGES:
            lead = words(article["lead"][l])
            baby = lead + sum(words(p) for f in ("sizeNote", "development") for p in article[f][l])
            mom = sum(words(p) for f in ("body", "todo") for p in article[f][l])
            print(f"week {week} {l}: lead {lead}, baby {baby}, mom {mom}")
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
