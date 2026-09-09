#!/bin/sh
# LarzOS - larz-install wrapper.
exec env LARZSCRIPT_PATH=/usr/lib/larzos larzscript /usr/lib/larzos/larz-install.lz "$@"
