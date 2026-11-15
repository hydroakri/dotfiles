"""Push entries of feeds that sites block for datacenter IPs into Miniflux.

Run from a home network. For each FEED_ID=URL pair the original RSS/Atom feed
is fetched here and every new item is POSTed to Miniflux's Import Entry
endpoint, so the entries appear under the existing Miniflux feed FEED_ID.

usage: miniflux-push-blocked --key-file F --state-dir D [--base-url U] [--dry-run] FEED_ID=URL ...
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

UA = "miniflux-push-blocked/1 (home fetch for a self-hosted Miniflux)"
MAX_BODY = 8 * 1024 * 1024
FRESH_DAYS = 7  # on the first run, older items are imported as already read
STATE_KEEP = 1000  # ids remembered per feed


def local(tag):
    return tag.rsplit("}", 1)[-1] if isinstance(tag, str) else ""


def text_of(el):
    return (el.text or "").strip() if el is not None else ""


def child(el, *names):
    for c in el:
        if local(c.tag) in names:
            return c
    return None


def parse_date(s):
    s = (s or "").strip()
    if not s:
        return None
    try:
        d = parsedate_to_datetime(s)
    except Exception:
        try:
            d = datetime.fromisoformat(s.replace("Z", "+00:00"))
        except Exception:
            return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def atom_link(el):
    best = ""
    for c in el:
        if local(c.tag) == "link":
            rel = c.get("rel", "alternate")
            if rel == "alternate" and c.get("href"):
                return c.get("href")
            best = best or c.get("href", "")
    return best


def parse_feed(data):
    root = ET.fromstring(data)
    items = []
    for el in root.iter():
        kind = local(el.tag)
        if kind not in ("item", "entry"):
            continue
        if kind == "item":
            link = text_of(child(el, "link"))
            guid = text_of(child(el, "guid")) or link
            content = text_of(child(el, "encoded")) or text_of(child(el, "description"))
            author = text_of(child(el, "creator", "author"))
            when = parse_date(text_of(child(el, "pubDate", "date")))
        else:
            link = atom_link(el)
            guid = text_of(child(el, "id")) or link
            content = text_of(child(el, "content")) or text_of(child(el, "summary"))
            a = child(el, "author")
            author = text_of(child(a, "name")) if a is not None else ""
            when = parse_date(text_of(child(el, "published", "updated")))
        if not link:
            continue
        items.append(
            {
                "guid": guid,
                "url": link,
                "title": text_of(child(el, "title")) or link,
                "author": author,
                "content": content,
                "when": when,
            }
        )
    items.sort(key=lambda i: i["when"] or datetime.fromtimestamp(0, timezone.utc))
    return items


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read(MAX_BODY + 1)
    if len(data) > MAX_BODY:
        raise ValueError("feed larger than limit")
    return data


class MinifluxError(Exception):
    pass


class Miniflux:
    def __init__(self, base, key, prefix):
        self.base, self.key, self.prefix = base.rstrip("/"), key, prefix

    def import_entry(self, feed_id, payload):
        """Return 201 (created) or 200 (existed). Tries /v1 then no prefix."""
        order = [self.prefix] + [p for p in ("/v1", "") if p != self.prefix]
        last = None
        for prefix in order:
            url = f"{self.base}{prefix}/feeds/{feed_id}/entries/import"
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode(),
                method="POST",
                headers={
                    "Content-Type": "application/json",
                    "X-Auth-Token": self.key,
                    "User-Agent": UA,
                },
            )
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    self.prefix = prefix
                    return r.status
            except urllib.error.HTTPError as e:
                if e.code in (401, 403):
                    raise MinifluxError(f"auth rejected (HTTP {e.code}); check the API key")
                if e.code == 404:
                    last = e
                    continue
                raise MinifluxError(f"HTTP {e.code} from {prefix or '(no prefix)'} path")
        raise MinifluxError(f"import endpoint not found under /v1 or without prefix ({last})")


def load_state(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"prefix": "/v1", "feeds": {}}


def save_state(path, state):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f)
    os.replace(tmp, path)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--key-file", required=True)
    ap.add_argument("--state-dir", required=True)
    ap.add_argument("--base-url", default="https://rss.hydroakri.cc")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("feeds", nargs="+", metavar="FEED_ID=URL")
    args = ap.parse_args(argv[1:])

    with open(args.key_file, encoding="utf-8") as f:
        key = f.read().strip()
    state_path = os.path.join(args.state_dir, "state.json")
    state = load_state(state_path)
    api = Miniflux(args.base_url, key, state.get("prefix", "/v1"))
    now = datetime.now(timezone.utc)
    failed = 0

    for spec in args.feeds:
        fid, _, url = spec.partition("=")
        if not fid.isdigit() or not url.startswith("http"):
            print(f"{spec}: bad FEED_ID=URL", file=sys.stderr)
            failed += 1
            continue
        try:
            items = parse_feed(fetch(url))
        except Exception as e:
            print(f"feed {fid}: fetch/parse failed ({e})", file=sys.stderr)
            failed += 1
            continue
        known = state["feeds"].get(fid)
        first_run = known is None
        seen = list(known or [])
        pushed = skipped = errors = 0
        for it in items:
            if it["guid"] in seen:
                skipped += 1
                continue
            old = it["when"] is not None and (now - it["when"]).days >= FRESH_DAYS
            payload = {
                "title": it["title"],
                "url": it["url"],
                "author": it["author"],
                "content": it["content"],
                "external_id": it["guid"],
                "status": "read" if (first_run and old) else "unread",
                "starred": False,
            }
            if it["when"] is not None:
                payload["published_at"] = int(it["when"].timestamp())
            if args.dry_run:
                print(f"feed {fid}: would push [{payload['status']}] {it['title'][:70]}")
                pushed += 1
                continue
            try:
                api.import_entry(fid, payload)
            except MinifluxError as e:
                print(f"feed {fid}: {e}", file=sys.stderr)
                errors += 1
                if "auth rejected" in str(e) or "not found" in str(e):
                    break  # same failure for every remaining item
                continue
            seen.append(it["guid"])
            pushed += 1
        print(f"feed {fid}: {len(items)} items, pushed {pushed}, already known {skipped}, errors {errors}")
        if errors:
            failed += 1
        if not args.dry_run:
            state["feeds"][fid] = seen[-STATE_KEEP:]
            state["prefix"] = api.prefix

    if not args.dry_run:
        os.makedirs(args.state_dir, exist_ok=True)
        save_state(state_path, state)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
