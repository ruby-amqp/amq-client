# encoding: utf-8

source :rubygems

# Use local clones if possible.
def custom_gem(name, options = Hash.new)
  local_path = File.expand_path("../../#{name}", __FILE__)
  if ENV["USE_AMQP_CUSTOM_GEMS"] && File.directory?(local_path)
    gem name, options.merge(:path => local_path).delete_if { |key, _| [:git, :branch].include?(key) }
  else
    gem name, options
  end
end

gem "eventmachine", "0.12.10" #, "1.0.0.beta.3"
# cool.io uses iobuffer that won't compile on JRuby
# (and, probably, Windows)
gem "cool.io", :platform => :ruby
custom_gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group :development do
  gem "yard"
  # yard tags this buddy along
  gem "RedCloth"

  gem "nake",          :platform => :ruby_19
  gem "contributors",  :platform => :ruby_19

  # excludes Windows and JRuby
  gem "perftools.rb",  :platform => :mri
end

group :test do
  gem "rspec", ">=2.0.0"
  gem "autotest"
  custom_gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
end
