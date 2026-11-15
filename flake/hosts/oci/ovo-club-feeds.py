"""Convert ovo.st/club/<group> pages into Atom files.

ovo.st groups are ActivityPub groups with no RSS. Each group page lists the
latest ~20 announced posts as `[YYYY-MM-DD HH:MM:SS] <a href=POST_URL>AUTHOR: TEXT</a>`.

usage: ovo-club-feeds OUT_DIR GROUP [GROUP ...]
Writes OUT_DIR/GROUP.xml atomically; a failed fetch or parse keeps the previous
file and makes the exit status non-zero.
"""

import html
import os
import re
import sys
import tempfile
import urllib.request
from datetime import datetime, timedelta, timezone
from xml.sax.saxutils import escape

BASE = os.environ.get("OVO_CLUB_BASE", "https://ovo.st/club/")
TZ = timezone(timedelta(hours=8))  # page timestamps are UTC+8
UA = "ovo-club-feeds/1 (+https://rss.hydroakri.cc)"
MARKER = "近期活动"
GROUP_RE = re.compile(r"^[a-z0-9_-]+$")
XML_BAD = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
ENTRY = re.compile(
    r"<p>\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\]\s*"
    r'<a href="([^"]+)"[^>]*>(.*?)</a></p>',
    re.S,
)


def cf_decode(hexstr):
    """Reverse Cloudflare email obfuscation: first byte is the XOR key."""
    raw = bytes.fromhex(hexstr)
    return bytes(c ^ raw[0] for c in raw[1:]).decode("utf-8", "replace")


def clean(text):
    return XML_BAD.sub("", text)


def fetch(group):
    req = urllib.request.Request(BASE + group, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read().decode("utf-8", "replace")


def parse(page):
    if MARKER not in page:
        raise ValueError("page has no recent-activity block")
    items = []
    for stamp, url, inner in ENTRY.findall(page):
        m = re.search(r'data-cfemail="([0-9a-f]+)"', inner)
        author = cf_decode(m.group(1)) if m else ""
        text = re.sub(
            r'<span class="__cf_email__"[^>]*>.*?</span>', "", inner, flags=re.S
        )
        text = html.unescape(re.sub(r"<[^>]+>", "", text)).lstrip(": ").strip()
        when = datetime.strptime(stamp, "%Y-%m-%d %H:%M:%S").replace(tzinfo=TZ)
        items.append(
            {"when": when, "url": html.unescape(url), "author": author, "text": text}
        )
    items.sort(key=lambda i: i["when"], reverse=True)
    return items


def page_title(page, group):
    m = re.search(r"<title>([^<]*)</title>", page)
    return html.unescape(m.group(1)).strip() if m else group


def to_atom(group, page, items):
    updated = items[0]["when"] if items else datetime.now(TZ)
    out = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<feed xmlns="http://www.w3.org/2005/Atom">',
        f"<title>{escape(clean(page_title(page, group)))}</title>",
        f'<link rel="alternate" href="{BASE}{group}"/>',
        f"<id>{BASE}{group}</id>",
        f"<updated>{updated.isoformat()}</updated>",
    ]
    for i in items:
        flat = clean(i["text"]).replace("\n", " ")
        title = flat[:70] + ("…" if len(flat) > 70 else "")
        out += [
            "<entry>",
            f"<title>{escape(title)}</title>",
            f'<link rel="alternate" href="{escape(i["url"])}"/>',
            f"<id>{escape(i['url'])}</id>",
            f"<updated>{i['when'].isoformat()}</updated>",
            f"<author><name>{escape(clean(i['author']) or 'unknown')}</name></author>",
            f'<content type="text">{escape(clean(i["text"]))}</content>',
            "</entry>",
        ]
    out.append("</feed>")
    return "\n".join(out) + "\n"


def write_atomic(path, data):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    out_dir, groups = argv[1], argv[2:]
    failed = 0
    for group in groups:
        if not GROUP_RE.match(group):
            print(f"{group}: invalid group name", file=sys.stderr)
            failed += 1
            continue
        try:
            page = fetch(group)
            items = parse(page)
            write_atomic(
                os.path.join(out_dir, group + ".xml"), to_atom(group, page, items)
            )
            print(f"{group}: {len(items)} entries")
        except Exception as e:  # keep the previous file on any failure
            print(f"{group}: FAILED, kept previous file ({e})", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
