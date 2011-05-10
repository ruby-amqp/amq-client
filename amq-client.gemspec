#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require File.expand_path("../lib/amq/client/version", __FILE__)

Gem::Specification.new do |s|
  s.name = "amq-client"
  s.version = AMQ::Client::VERSION.dup
  s.authors = ["Jakub Stastny", "Michael S. Klishin", "Theo Hultberg", "Mark Abramov"]
  s.email   = [Base64.decode64("c3Rhc3RueUAxMDFpZGVhcy5jeg==\n"), "michael@novemberain.com"]
  s.homepage = "http://github.com/ruby-amqp/amq-client"
  s.summary = "amq-client is a fully-featured, low-level AMQP 0.9.1 client"
  s.description = "amq-client supports multiple networking adapters (EventMachine, TCP sockets, cool.io) and supposed to back more opinionated AMQP clients (such as amqp gem, bunny, et cetera) or be used directly in cases when access to more advanced AMQP 0.9.1 features is more important that convenient APIs"
  s.cert_chain = nil

  # files
  s.files = `git ls-files`.split("\n").reject { |file| file =~ /^vendor\// || file =~ /^gemfiles\// }
  s.require_paths = ["lib"]
  s.extra_rdoc_files = ["README.textile"] + Dir.glob("doc/*")

  # Dependencies
  s.add_dependency "eventmachine"
  s.add_dependency "amq-protocol"


  # RubyForge
  s.rubyforge_project = "amq-client"
end
