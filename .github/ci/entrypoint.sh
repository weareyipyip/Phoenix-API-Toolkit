#!/bin/sh

# halt on errors and undefined variables
set -eu

# install dependencies
mix do local.hex --force, local.rebar --force, deps.get

# let's go
mix test --cover

# create docs, just to check that it succeeds
MIX_ENV=test mix docs