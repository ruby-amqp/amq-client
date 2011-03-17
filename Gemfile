# encoding: utf-8

source :rubygems

gem "eventmachine", "0.12.10" #, "1.0.0.beta.3"
gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group :development do
  gem "yard"
  # yard tags this buddy along
  gem "RedCloth"
  # cool.io uses iobuffer that won't compile on JRuby
  # (and, probably, Windows)
  gem "cool.io",       :platform => :ruby

  gem "nake",          :platform => :ruby_19
  gem "contributors",  :platform => :ruby_19

  # excludes Windows and JRuby
  gem "perftools.rb",  :platform => :ruby
end

group :test do
  gem "rspec", ">=2.0.0"
  gem "autotest"
  gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
end
