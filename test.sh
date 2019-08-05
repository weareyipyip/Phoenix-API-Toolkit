#!/bin/sh

if [ -z ${1+x} ]
then
    docker-compose up
else
    docker-compose run --rm phoenix_api_toolkit_$1 /bin/sh -c "mix do local.hex --force, local.rebar --force, deps.get, test"
fi
