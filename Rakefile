require 'rspec/core/rake_task'

desc "Run spec suite (uses Rspec2)"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/**/*_spec.rb"
end

desc "Run spec suit (default)"
task :default => :spec