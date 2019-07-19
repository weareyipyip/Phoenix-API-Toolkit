#!/bin/sh

# halt on errors and undefined variables
set -eu

echo
echo "***** Environment *****"
echo
printenv
echo
echo "***********************"
echo

echo "***** Install dependencies... *****"
mix do local.hex --force, local.rebar --force, deps.get
echo

echo "***** Running tests... *****"
mix test --cover
echo

# create docs, just to check that it succeeds
echo "***** Creating docs... *****"
MIX_ENV=test mix docs
echo