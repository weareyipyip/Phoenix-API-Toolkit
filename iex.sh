#!/bin/sh

ELIXIR_VERSION=${1:-1.9}

docker-compose run --rm phoenix_api_toolkit_$ELIXIR_VERSION /bin/sh -c "mix do local.hex --force, local.rebar --force, deps.get && iex -S mix"