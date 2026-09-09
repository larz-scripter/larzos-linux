#!/bin/sh
# refresh.sh - rebuild every package from a clean checkout and republish the
# apt repo. Run on the repo host as root.
#
#   sh tools/refresh.sh            # from an existing checkout
#   curl -fsSL https://raw.githubusercontent.com/larz-scripter/larzos-linux/main/tools/refresh.sh | sh
set -eu
WORK="${WORK:-/root/larzos-linux-build}"

if [ -d "$WORK/.git" ]; then
  git -C "$WORK" pull --ff-only
else
  rm -rf "$WORK"
  git clone https://github.com/larz-scripter/larzos-linux "$WORK"
fi

cd "$WORK"
export LARZSCRIPT_PATH=lib
make clean
make packages
sh tools/repo-publish.sh
