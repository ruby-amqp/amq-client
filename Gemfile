# encoding: utf-8

source :rubygems

# Use local clones if possible.
# If you want to use your local copy, just symlink it to vendor.
# See http://blog.101ideas.cz/posts/custom-gems-in-gemfile.html
extend Module.new {
  def gem(name, *args)
    options = args.last.is_a?(Hash) ? args.last : Hash.new

    local_path = File.expand_path("../vendor/#{name}", __FILE__)
    if File.exist?(local_path)
      super name, options.merge(:path => local_path).
        delete_if { |key, _| [:git, :branch].include?(key) }
    else
      super name, *args
    end
  end
}

gem "eventmachine"
# cool.io uses iobuffer that won't compile on JRuby
# (and, probably, Windows)
gem "cool.io", :platform => :ruby
gem "amq-protocol", :git => "git://github.com/ruby-amqp/amq-protocol.git", :branch => "master"

group :development do
  gem "yard"
  # yard tags this buddy along
  gem "RedCloth", :platform => :mri

  gem "nake",          :platform => :ruby_19
  # excludes Windows and JRuby
  gem "perftools.rb",  :platform => :mri
end

group :test do
  gem "rspec", ">= 2.6.0"
  gem "evented-spec", :git => "git://github.com/ruby-amqp/evented-spec.git", :branch => "master"
  gem "effin_utf8"

  gem "multi_json"

  gem "json",      :platform => :jruby
  gem "yajl-ruby", :platform => :ruby_18
end
