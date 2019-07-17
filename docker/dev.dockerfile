FROM elixir:1.9-alpine

RUN mix local.hex --force && \
    mix local.rebar --force