#!/usr/bin/env gem build
# encoding: utf-8

require "base64"

Gem::Specification.new do |s|
  s.name = "amq-client"
  s.version = "0.2.0"
  s.authors = ["Jakub Stastny", "Michael S. Klishin"]
  s.email   = ["michael@novemberain.com"]
  s.homepage = "http://github.com/ruby-amqp/amq-client"
  s.summary = "Low-level AMQP 0.9.1 client agnostic to the used IO library."
  s.description = "Very low-level AMQP 0.9.1 client which is supposed to be used for implementing more high-level AMQP libraries rather than to be used by the end users."
  s.cert_chain = nil
  s.email = Base64.decode64("c3Rhc3RueUAxMDFpZGVhcy5jeg==\n")
  s.has_rdoc = true

  # files
  s.files = `git ls-files`.split("\n").reject {|file| file =~ /^vendor\// }
  s.require_paths = ["lib"]

  begin
    require "changelog"
  rescue LoadError
    warn "You have to have changelog gem installed for post install message"
  else
    s.post_install_message = CHANGELOG.new.version_changes
  end

  # RubyForge
  s.rubyforge_project = "amq-client"
end
