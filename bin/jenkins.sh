#!/bin/bash

echo "==== Setup ===="
git fetch && git reset origin/master --hard
bundle install --local

echo "\n\n==== Ruby 1.9.2 Head ===="
rvm 1.9.2-head exec rspec spec

echo "\n\n==== Ruby 1.8.7 ===="
rvm 1.8.7 exec rspec spec
