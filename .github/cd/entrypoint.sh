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

echo "***** Check versions *****"
mix run .github/cd/check_versions.exs README.md

echo "***** Running tests... *****"
mix test
echo

echo "***** Publishing release... *****"
mix hex.publish --yes
echo