#!/bin/sh

# halt on errors and undefined variables
set -eu

# install dependencies
mix do local.hex --force, local.rebar --force, deps.get

# let's go
mix hex.publish --yes --dry-run