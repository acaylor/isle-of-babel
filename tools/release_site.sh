#!/usr/bin/env bash
# Refresh the project site (gh-pages) for a release: re-render every plate
# from tools/plates.manifest, stamp the version badge and latest-release
# link from Game.VERSION, optionally add a release-timeline chapter, then
# commit gh-pages and push it to BOTH remotes (the documented mirror
# exception). Run after tagging, from anywhere inside the repo:
#
#   tools/release_site.sh --chapter "The living world" "One-line blurb."
#   tools/release_site.sh --no-push        # render + stamp, leave unpushed
#
# The plates land byte-identical per version because the world generation
# is seeded; a framing only changes when the manifest or the world does.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/tools/plates.manifest"
FRAME=7

CHAPTER_TITLE=""
CHAPTER_BLURB=""
PUSH=1
while [ $# -gt 0 ]; do
	case "$1" in
		--chapter) CHAPTER_TITLE="$2"; CHAPTER_BLURB="$3"; shift 3;;
		--no-push) PUSH=0; shift;;
		*) echo "unknown argument: $1" >&2; exit 2;;
	esac
done

VERSION="$(sed -n 's/^const VERSION := "\(.*\)"$/\1/p' "$ROOT/autoload/game.gd")"
[ -n "$VERSION" ] || { echo "could not read Game.VERSION" >&2; exit 1; }
echo "site release for v$VERSION"

WORK="$(mktemp -d)"
SITE="$WORK/gh-pages"
trap 'git -C "$ROOT" worktree remove --force "$SITE" 2>/dev/null || true; rm -rf "$WORK"' EXIT

# 1. Render every plate; keep frame $FRAME of each.
while IFS='|' read -r name scene spawn cam look; do
	case "$name" in ''|'#'*) continue;; esac
	echo "  plate: $name"
	env CAP_SCENE="$scene" CAP_SPAWN="$spawn" CAP_CAM="$cam" CAP_LOOK="$look" \
		"$GODOT" --path "$ROOT" res://tests/capture.tscn \
		--write-movie "$WORK/$name.png" --fixed-fps 10 --quit-after 8 >/dev/null 2>&1
	frame_file="$(printf '%s/%s%08d.png' "$WORK" "$name" "$FRAME")"
	[ -f "$frame_file" ] || { echo "render failed for plate '$name'" >&2; exit 1; }
	mv "$frame_file" "$WORK/plate_$name.png"
done < "$MANIFEST"

# 2. Copy plates into a gh-pages worktree.
git -C "$ROOT" worktree add "$SITE" gh-pages >/dev/null
for f in "$WORK"/plate_*.png; do
	base="$(basename "$f")"
	cp "$f" "$SITE/images/${base#plate_}.tmp" && mv "$SITE/images/${base#plate_}.tmp" "$SITE/images/${base#plate_}"
done

# 3. Stamp the badge, the latest-release link, and (optionally) a chapter.
python3 - "$SITE/index.html" "$VERSION" "$CHAPTER_TITLE" "$CHAPTER_BLURB" <<'PY'
import datetime, pathlib, re, sys
path, version, title, blurb = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
html = pathlib.Path(path).read_text()
out = []
for line in html.splitlines(keepends=True):
	if 'class="badge"' in line or ">Latest release</a>" in line:
		line = re.sub(r"v\d+\.\d+\.\d+-alpha", f"v{version}", line)
	out.append(line)
html = "".join(out)
# Idempotence guard: look for this version's chapter marker specifically.
# (Checking the release-tag URL is self-defeating: the latest-release
# button was just stamped with that URL a few lines up.)
short = re.sub(r"(\d+\.\d+\.\d+)-alpha", r"\1", version)
if title and f'<span class="ver">v{short}</span>' not in html:
	date = datetime.date.today().strftime("%B %Y").upper()
	chapter = (
		'  <div class="chapter">\n'
		f'    <span class="ver">v{short}</span>\n'
		"    <div>\n"
		f'      <h3><a href="https://github.com/acaylor/isle-of-babel/releases/tag/v{version}">{title}</a>'
		f'<span class="date">{date}</span></h3>\n'
		f"      <p>{blurb}</p>\n"
		"    </div>\n"
		"  </div>\n"
	)
	anchor = html.index('class="chapters')  # matches class="chapters reveal"
	close = html.index("</section>", anchor)
	html = html[:close] + chapter + html[close:]
pathlib.Path(path).write_text(html)
PY

# 4. Commit and push to both remotes.
git -C "$SITE" add -A
if git -C "$SITE" diff --cached --quiet; then
	echo "site already current for v$VERSION"
	exit 0
fi
git -C "$SITE" commit -m "Site: plates and badge for v$VERSION" >/dev/null
if [ "$PUSH" = 1 ]; then
	git -C "$SITE" push origin gh-pages
	git -C "$SITE" push github gh-pages
	echo "gh-pages pushed to both remotes"
else
	echo "committed on gh-pages (push skipped; push manually to both remotes)"
fi
