#!/bin/sh

set -e

if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

if [ -f tmp/pids/sidekiq.pid ]; then
  rm tmp/pids/sidekiq.pid
fi

exec "$@"
