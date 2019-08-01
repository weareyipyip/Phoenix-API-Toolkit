#!/bin/sh

MIX_ENV=test mix do deps.get, clean, compile, test