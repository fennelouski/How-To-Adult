#!/usr/bin/env python3
"""Check the public article catalog before bundling or publishing it."""

import argparse
import copy
import datetime as dt
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
REVISION = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,79}\Z")
DATE = re.compile(r"\d{4}-\d{2}-\d{2}\Z")
UTC_TIME = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z\Z")
TOP_KEYS = {"schemaVersion", "revision", "publishedAt", "categories", "articles"}
CATEGORY_KEYS = {"id", "title", "symbol", "colorKey"}
ARTICLE_KEYS = {
    "id", "title", "summary", "categoryID", "symbol", "minutes", "jurisdiction",
    "updatedAt", "tags", "tools", "steps", "cautions", "sources",
}
SOURCE_REQUIRED_CATEGORIES = {"money", "food", "wellbeing"}
SOURCE_REQUIRED_IDS = {
    "clean-a-bathroom", "test-your-smoke-alarms", "lower-home-energy-use",
    "check-your-first-pay-stub", "find-a-cheaper-phone-plan",
    "check-your-tire-pressure", "make-a-car-maintenance-plan",
    "check-a-vehicle-recall", "host-a-simple-dinner", "dry-clothes-with-care",
}
US_ONLY_IDS = {
    "understand-a-credit-card-bill", "check-your-credit-report",
    "gather-tax-documents", "find-free-tax-filing-help", "start-with-your-401k",
    "read-your-401k-fees", "check-your-first-pay-stub",
    "find-mental-health-support", "find-a-cheaper-phone-plan",
    "check-a-vehicle-recall",
}


def validate(catalog, minimum_articles=48):
    errors = []

    def problem(path, message):
        errors.append(f"{path}: {message}")

    def obj(value, keys, path):
        if not isinstance(value, dict):
            problem(path, "must be an object")
            return False
        if set(value) != keys:
            problem(path, f"keys must be {', '.join(sorted(keys))}")
        return True

    def text(value, path, limit=200):
        if not isinstance(value, str) or not value.strip() or value != value.strip():
            problem(path, "must be nonempty text without edge whitespace")
            return False
        if len(value) > limit:
            problem(path, f"exceeds {limit} characters")
        return True

    def slug(value, path):
        if not isinstance(value, str) or not SLUG.fullmatch(value):
            problem(path, "must be a lowercase kebab-case ID")
            return False
        return True

    def strings(value, path, limit=300, maximum=40):
        if not isinstance(value, list):
            problem(path, "must be an array")
            return
        if len(value) > maximum:
            problem(path, f"exceeds {maximum} entries")
        seen = set()
        for i, entry in enumerate(value):
            if text(entry, f"{path}[{i}]", limit):
                if entry in seen:
                    problem(path, "contains a duplicate entry")
                seen.add(entry)

    if not obj(catalog, TOP_KEYS, "catalog"):
        return errors
    if type(catalog.get("schemaVersion")) is not int or catalog.get("schemaVersion") != 1:
        problem("schemaVersion", "must be integer 1")
    revision = catalog.get("revision")
    if not isinstance(revision, str) or not REVISION.fullmatch(revision):
        problem("revision", "must be a safe, nonempty revision string of at most 80 characters")
    try:
        published = catalog.get("publishedAt")
        if not isinstance(published, str) or not UTC_TIME.fullmatch(published):
            raise ValueError()
        parsed = dt.datetime.fromisoformat(published[:-1] + "+00:00")
        if "T" not in published or parsed.utcoffset() != dt.timedelta(0):
            raise ValueError()
    except (ValueError, TypeError):
        problem("publishedAt", "must be an RFC3339 UTC timestamp ending in Z")

    categories = catalog.get("categories")
    category_ids = set()
    if not isinstance(categories, list) or not categories:
        problem("categories", "must be a nonempty array")
        categories = []
    for i, category in enumerate(categories):
        path = f"categories[{i}]"
        if not obj(category, CATEGORY_KEYS, path):
            continue
        cid = category.get("id")
        if slug(cid, path + ".id"):
            if cid in category_ids:
                problem(path + ".id", "duplicate category ID")
            category_ids.add(cid)
        for key in ("title", "symbol", "colorKey"):
            text(category.get(key), path + "." + key, 120)

    articles = catalog.get("articles")
    if not isinstance(articles, list):
        problem("articles", "must be an array")
        articles = []
    if len(articles) < minimum_articles:
        problem("articles", f"must contain at least {minimum_articles} guides")
    if len(articles) > 2000:
        problem("articles", "exceeds the current backend limit of 2000")
    article_ids, step_ids = set(), set()
    for i, article in enumerate(articles):
        path = f"articles[{i}]"
        if not obj(article, ARTICLE_KEYS, path):
            continue
        aid = article.get("id")
        if slug(aid, path + ".id"):
            if aid in article_ids:
                problem(path + ".id", "duplicate article ID")
            article_ids.add(aid)
        for key, limit in (("title", 120), ("summary", 240), ("symbol", 120), ("jurisdiction", 120)):
            text(article.get(key), path + "." + key, limit)
        cid = article.get("categoryID")
        if not isinstance(cid, str) or cid not in category_ids:
            problem(path + ".categoryID", "must refer to an existing category")
        minutes = article.get("minutes")
        if type(minutes) is not int or not 1 <= minutes <= 1440:
            problem(path + ".minutes", "must be an integer between 1 and 1440")
        updated = article.get("updatedAt")
        try:
            if not isinstance(updated, str) or not DATE.fullmatch(updated):
                raise ValueError()
            dt.date.fromisoformat(updated)
        except ValueError:
            problem(path + ".updatedAt", "must be a real ISO8601 date")
        for key in ("tags", "tools", "cautions"):
            strings(article.get(key), path + "." + key)
        steps = article.get("steps")
        if not isinstance(steps, list) or not 2 <= len(steps) <= 30:
            problem(path + ".steps", "must contain 2 to 30 steps")
            steps = []
        for j, step in enumerate(steps):
            spath = f"{path}.steps[{j}]"
            if not obj(step, {"id", "title", "body"}, spath):
                continue
            sid = step.get("id")
            if slug(sid, spath + ".id"):
                if sid in step_ids:
                    problem(spath + ".id", "step IDs must be globally unique")
                step_ids.add(sid)
            text(step.get("title"), spath + ".title", 120)
            text(step.get("body"), spath + ".body", 2000)
        sources = article.get("sources")
        if not isinstance(sources, list) or len(sources) > 20:
            problem(path + ".sources", "must be an array of at most 20 sources")
            sources = []
        safe_cid = cid if isinstance(cid, str) else ""
        safe_aid = aid if isinstance(aid, str) else ""
        if (safe_cid in SOURCE_REQUIRED_CATEGORIES or safe_aid in SOURCE_REQUIRED_IDS) and not sources:
            problem(path + ".sources", "this sensitive guide requires a primary source")
        source_urls = set()
        for j, source in enumerate(sources):
            spath = f"{path}.sources[{j}]"
            if not obj(source, {"title", "url"}, spath):
                continue
            text(source.get("title"), spath + ".title", 200)
            url = source.get("url")
            if text(url, spath + ".url", 2048):
                try:
                    parts = urlsplit(url)
                    if parts.scheme != "https" or not parts.hostname or parts.username or parts.password:
                        raise ValueError()
                    if any(char.isspace() or ord(char) < 32 for char in url):
                        raise ValueError()
                    if parts.port is not None and not 1 <= parts.port <= 65535:
                        raise ValueError()
                    if parts.hostname in {"localhost", "127.0.0.1", "::1"}:
                        raise ValueError()
                except ValueError:
                    problem(spath + ".url", "must be a public HTTPS URL without credentials")
                if url in source_urls:
                    problem(spath + ".url", "duplicate source URL")
                source_urls.add(url)
        if safe_aid in US_ONLY_IDS and article.get("jurisdiction") != "United States":
            problem(path + ".jurisdiction", "this US-specific guide must say United States")
    return errors


def self_test(catalog):
    cases = {
        "duplicate article": lambda c: c["articles"].append(copy.deepcopy(c["articles"][0])),
        "unknown category": lambda c: c["articles"][0].update(categoryID="missing"),
        "duplicate step": lambda c: c["articles"][1]["steps"][0].update(id=c["articles"][0]["steps"][0]["id"]),
        "missing money source": lambda c: next(a for a in c["articles"] if a["categoryID"] == "money").update(sources=[]),
        "wrong US scope": lambda c: next(a for a in c["articles"] if a["id"] == "start-with-your-401k").update(jurisdiction="General"),
        "invalid date": lambda c: c["articles"][0].update(updatedAt="2026-02-30"),
        "boolean minutes": lambda c: c["articles"][0].update(minutes=True),
        "HTTP source": lambda c: c["articles"][0]["sources"][0].update(url="http://example.com"),
        "credential source": lambda c: c["articles"][0]["sources"][0].update(url="https://user:password@example.com"),
        "unknown article key": lambda c: c["articles"][0].update(typo="unexpected"),
        "one step": lambda c: c["articles"][0].update(steps=c["articles"][0]["steps"][:1]),
        "object article ID": lambda c: c["articles"][0].update(id={"invalid": "type"}),
        "array category ID": lambda c: c["articles"][0].update(categoryID=["home"]),
        "source whitespace": lambda c: c["articles"][0]["sources"][0].update(url="https://example.com/a b"),
        "invalid source port": lambda c: c["articles"][0]["sources"][0].update(url="https://example.com:not-a-port"),
        "incomplete timestamp": lambda c: c.update(publishedAt="2026-10-03T04:50Z"),
    }
    for name, mutate in cases.items():
        changed = copy.deepcopy(catalog)
        mutate(changed)
        if not validate(changed):
            raise AssertionError(f"validator accepted {name}")
    print(f"Validator rejection checks passed: {len(cases)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", nargs="?", type=Path, default=ROOT / "Content/catalog.json")
    parser.add_argument("--minimum-articles", type=int, default=48)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        data = args.catalog.read_bytes()
        if len(data) > 4 * 1024 * 1024:
            raise ValueError("catalog exceeds 4 MiB")
        catalog = json.loads(data)
        errors = validate(catalog, args.minimum_articles)
    except (OSError, ValueError, UnicodeDecodeError) as error:
        print(f"Invalid catalog: {error}", file=sys.stderr)
        return 1
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    if args.self_test:
        self_test(catalog)
    source_urls = {s["url"] for a in catalog["articles"] for s in a["sources"]}
    print(f"Catalog valid: {len(catalog['articles'])} guides, {len(catalog['categories'])} categories, {len(source_urls)} distinct source URLs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
