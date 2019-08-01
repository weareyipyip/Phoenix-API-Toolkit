FROM elixir:1.7-alpine

RUN mix local.hex --force && \
    mix local.rebar --force