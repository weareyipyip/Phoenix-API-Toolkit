#!/bin/sh

# halt on errors and undefined variables
set -eu

echo "***************"
echo "* Environment *"
echo "***************"
echo
printenv
echo
echo "Done."
echo

echo "******************************"
echo "* Installing dependencies... *"
echo "******************************"
echo
mix do local.hex --force, local.rebar --force, deps.get
echo
echo "Done."
echo

echo "************************"
echo "* Checking versions... *"
echo "************************"
echo
mix run .github/cd/check_versions.exs README.md
echo "Done."
echo

echo "****************"
echo "* Compiling... *"
echo "****************"
echo
MIX_ENV=test mix compile --warnings-as-errors
echo
echo "Done."
echo

echo "*************************"
echo "* Running mix format... *"
echo "*************************"
echo
MIX_ENV=test mix format --check-formatted
echo "Done."
echo

echo "********************"
echo "* Running tests... *"
echo "********************"
echo
MIX_ENV=test mix test --cover
echo "Done."
echo

echo "***********************"
echo "* Running Dialyzer... *"
echo "***********************"
echo
MIX_ENV=test mix dialyzer --halt-exit-status
echo
echo "Done."
echo

echo "********************"
echo "* Creating docs... *"
echo "********************"
echo
MIX_ENV=test mix docs
echo "Done."
echo

echo "**********************"
echo "* Publish package... *"
echo "**********************"
echo
mix hex.publish --yes
echo "Done."
echo