#!/bin/sh

grep -e 'version: "' ./mix.exs | sed -n 's/version\: \"\([[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*\)\".*/\1/p' | head -1 | awk '{$1=$1;print}'
