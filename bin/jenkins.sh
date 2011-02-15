#!/bin/bash

echo -e "\n\n==== Setup ===="
git fetch && git reset origin/master --hard
bundle install --local

echo -e "\n\n==== Ruby 1.9.2 Head ===="
rvm 1.9.2-head exec rspec spec

echo -e "\n\n==== Ruby 1.8.7 ===="
rvm 1.8.7 exec rspec spec
