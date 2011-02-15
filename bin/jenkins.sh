#!/bin/bash

# Server-specific, I have RVM setup at the profile file:
source /etc/profile

echo "<h3>Setup</h3>"
git fetch && git reset origin/master --hard
bundle install --local

echo "<h3>Ruby 1.9.2 Head</h3>"
rvm 1.9.2-head exec rspec spec

echo "<h3>Ruby 1.8.7</h3>"
rvm 1.8.7 exec rspec spec
