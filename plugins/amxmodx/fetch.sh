#!/bin/sh
# fetch.sh <url> <commit> <dir>: check out just that commit, without history
set -eu
git init -q "$3"
git -C "$3" remote add origin "$1"
git -C "$3" fetch -q --depth 1 origin "$2"
git -C "$3" checkout -q FETCH_HEAD
