"""Convert a GitHub repository's issues into Atom files.

GitHub removed the per-repo issues Atom feed and public RSSHub instances sit
behind bot checks, so the issues API is polled instead.

usage: github-issues-feed OUT_DIR OWNER/REPO [OWNER/REPO ...]
Writes OUT_DIR/OWNER-REPO.xml atomically; a failed fetch keeps the previous
file and makes the exit status non-zero.
"""

import json
import os
import re
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone
from xml.sax.saxutils import escape, quoteattr

API = "https://api.github.com/repos/{}/issues?state=all&sort=created&direction=desc&per_page=30"
UA = "github-issues-feed/1 (+https://rss.hydroakri.cc)"
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
XML_BAD = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")


def clean(text):
    return XML_BAD.sub("", text or "")


def fetch(repo):
    req = urllib.request.Request(
        API.format(repo),
        headers={
            "User-Agent": UA,
            "Accept": "application/vnd.github.html+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.load(resp)
    if not isinstance(data, list):
        raise ValueError("unexpected API response")
    # the issues endpoint also lists pull requests
    return [i for i in data if "pull_request" not in i]


def to_atom(repo, issues):
    updated = max((i["updated_at"] for i in issues), default=None) or datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")
    out = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<feed xmlns="http://www.w3.org/2005/Atom">',
        f"<title>{escape(repo)} issues</title>",
        f"<link rel=\"alternate\" href={quoteattr('https://github.com/' + repo + '/issues')}/>",
        f"<id>https://github.com/{repo}/issues</id>",
        f"<updated>{updated}</updated>",
    ]
    for i in issues:
        out += [
            "<entry>",
            f"<title>{escape(clean(i['title']))}</title>",
            f'<link rel="alternate" href={quoteattr(i["html_url"])}/>',
            f"<id>{escape(i['html_url'])}</id>",
            f"<published>{i['created_at']}</published>",
            f"<updated>{i['created_at']}</updated>",
            f"<author><name>{escape(clean(i['user']['login']))}</name></author>",
            f'<content type="html">{escape(clean(i.get("body_html")))}</content>',
            "</entry>",
        ]
    out.append("</feed>")
    return "\n".join(out) + "\n"


def write_atomic(path, text):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def main(argv):
    if len(argv) < 3:
        print(__doc__.strip().splitlines()[-4], file=sys.stderr)
        return 2
    out_dir, failed = argv[1], 0
    for repo in argv[2:]:
        if not REPO_RE.match(repo):
            print(f"{repo}: bad OWNER/REPO", file=sys.stderr)
            failed += 1
            continue
        try:
            issues = fetch(repo)
            write_atomic(
                os.path.join(out_dir, repo.replace("/", "-") + ".xml"),
                to_atom(repo, issues),
            )
        except Exception as e:
            print(f"{repo}: {e}", file=sys.stderr)
            failed += 1
            continue
        print(f"{repo}: {len(issues)} issues")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
