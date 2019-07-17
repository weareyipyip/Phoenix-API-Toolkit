#!/bin/sh

mix do deps.get, clean, compile

iex -S mix