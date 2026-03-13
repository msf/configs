#!/bin/sh
# usage: strip-conflict.sh FILE...
for f; do
  sed -E '/^(<<<<<<<|=======|>>>>>>>|\|{7})/d' "$f" > "$f.$$" && mv "$f.$$" "$f"
done
