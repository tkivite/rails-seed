#!/usr/bin/env bash

if [[ $DYNO == "web"* ]]; then
  rails server
elif  [[ $DYNO == "worker"* ]]; then
  bundle exec sidekiq -q critical,4 -q default,2 -q mailers,1 -q low,1
fi
