#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/amq/client/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "amq-client"
  s.version = AMQ::Client::VERSION.dup
  s.authors = ["Jakub Stastny", "Michael S. Klishin"]
  s.email   = [Base64.decode64("c3Rhc3RueUAxMDFpZGVhcy5jeg==\n"), "michael@novemberain.com"]
  s.homepage = "http://github.com/ruby-amqp/amq-client"
  s.summary = "Low-level AMQP 0.9.1 client"
  s.description = <<-DESC
  amq-client supports multiple networking adapters (EventMachine, TCP sockets, cool.io) and
  supposed to back more opinionated AMQP clients (such as amqp gem, bunny, et cetera) or be used directly
  in cases when access to more advanced AMQP 0.9.1 features is more important that convenient APIs
  DESC
  s.cert_chain = nil
  s.has_rdoc   = true

  # files
  s.files = `git ls-files`.split("\n").reject { |file| file =~ /^vendor\// }
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
