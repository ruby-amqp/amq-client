# encoding: utf-8

source :rubygems

gem "eventmachine", "0.12.10" #, "1.0.0.beta.3"
gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group :development do
  gem "yard"
  # yard tags this buddy along
  gem "RedCloth"
  gem "cool.io" # , :path => "vendor/cool.io"

  gem "nake",          :platform => :ruby_19
  gem "contributors",  :platform => :ruby_19

  gem "perftools.rb"
end

group :test do
  gem "rspec", ">=2.0.0"
  gem "autotest"
  gem "evented-spec", :path => "vendor/evented-spec"
end
