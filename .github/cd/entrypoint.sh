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

MIX_VERSION=$(.github/cd/get_version.sh)
EXP_GIT_REF=refs/tags/v$MIX_VERSION

echo "Version in mixfile: $MIX_VERSION"
if test "$GITHUB_REF" = "$EXP_GIT_REF"; then
  echo "Mix file version matches git tag, continuing..."
  echo
else
  echo "Expected git ref $EXP_GIT_REF but instead it's $GITHUB_REF, aborting."
  echo "Please make sure the release tag equals 'v<mix file version>', for example v0.1.0 for mix file version 0.1.0"
  exit 1
fi

echo "***** Install dependencies... *****"
mix do local.hex --force, local.rebar --force, deps.get
echo

echo "***** Running tests... *****"
mix test
echo

echo "***** Publishing release... *****"
mix hex.publish --yes
echo