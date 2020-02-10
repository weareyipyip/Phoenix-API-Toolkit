#!/bin/sh

# halt on errors and undefined variables
set -eu

export MIX_ENV=test

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

echo "****************"
echo "* Compiling... *"
echo "****************"
echo
mix compile --warnings-as-errors
echo
echo "Done."
echo

echo "*************************"
echo "* Running mix format... *"
echo "*************************"
echo
mix format --check-formatted
echo "Done."
echo

echo "********************"
echo "* Running tests... *"
echo "********************"
echo
mix test --cover
echo "Done."
echo

echo "***********************"
echo "* Running Dialyzer... *"
echo "***********************"
echo
mix dialyzer
echo
echo "Done."
echo