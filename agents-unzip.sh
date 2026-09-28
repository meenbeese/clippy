#!/bin/sh
#
# agents-unzip.sh
#
# Unpacks the *.agent.zip archives in Clippy's Agents directory.
#
# The app only *copies* the bundled archives into the Agents folder on first
# launch (see Agent.createAgentsDirectoriesIfNeeded) — it never extracts them,
# and Agent.agentNames() only lists *directories* ending in .agent. This
# script performs that step, the same thing the README asks you to do by hand
# via "Show in Finder".
#
# Usage: ./agents-unzip.sh [OPTIONS] [AGENTS_DIR]
#

set -e

AGENTS_DIR="${AGENTS_DIR:-$HOME/Library/Application Support/Clippy/Agents}"
FORCE=0

usage() {
  echo "Usage: $(basename "$0") [-f|--force] [AGENTS_DIR]"
  echo ""
  echo "  AGENTS_DIR  defaults to \$HOME/Library/Application Support/Clippy/Agents"
  echo "  -f, --force re-extract agents that are already unpacked"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) AGENTS_DIR="$1" ;;
  esac
  shift
done

if [ ! -d "$AGENTS_DIR" ]; then
  echo "Agents directory not found: $AGENTS_DIR" >&2
  echo "Run the app once first, or pass the path explicitly." >&2
  exit 1
fi

set -- "$AGENTS_DIR"/*.agent.zip
if [ ! -e "$1" ]; then
  echo "No *.agent.zip archives in $AGENTS_DIR"
  exit 0
fi

for archive in "$@"; do
  folder=$(basename "$archive" .zip)          # e.g. clippit.agent
  name=${folder%.agent}                       # e.g. clippit
  target="$AGENTS_DIR/$folder"

  if [ -d "$target" ] && [ "$FORCE" -eq 0 ]; then
    echo "SKIP  $folder  (already extracted, use --force to overwrite)"
    continue
  fi

  echo "UNZIP $archive"
  rm -rf "$target"
  # NB: the archive has to precede -x/-d, otherwise unzip parses the exclude
  # patterns as additional zipfiles to open.
  unzip -q -o "$archive" -d "$AGENTS_DIR" -x '__MACOSX/*' '*/.DS_Store'

  # Agent(resourceName:) needs <name>.acd and <name>_sprite_map.png to exist.
  if [ ! -f "$target/$name.acd" ] || [ ! -f "$target/${name}_sprite_map.png" ]; then
    echo "FAIL  $folder  (missing $name.acd or ${name}_sprite_map.png)" >&2
    exit 1
  fi

  echo "OK    $folder"
done

rm -rf "$AGENTS_DIR/__MACOSX"

echo ""
echo "Done. In the app: menu bar -> Reload, then Agents -> pick one."
