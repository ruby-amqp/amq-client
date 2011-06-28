#!/usr/bin/env ruby
# encoding: utf-8

examples_dir = File.join(File.dirname(File.expand_path(__FILE__)), "..", "..")
__dir        = File.join(File.dirname(File.expand_path(__FILE__)), "..")
require File.join(__dir, "example_helper")

certificate_chain_file_path  = File.join(examples_dir, "tls_certificates", "client", "cert.pem")
client_private_key_file_path = File.join(examples_dir, "tls_certificates", "client", "key.pem")

EM.run do
  AMQ::Client::EventMachineClient.connect(:port     => 5671,
                                          :vhost    => "amq_client_testbed",
                                          :user     => "amq_client_gem",
                                          :password => "amq_client_gem_password",
                                          :ssl => {
                                            :cert_chain_file  => certificate_chain_file_path,
                                            :private_key_file => client_private_key_file_path
                                          }) do |client|
    puts "Connected, authenticated. TLS seems to work."

    client.disconnect { puts "Now closing the connection…"; EM.stop }
  end


  show_stopper = Proc.new {
    EM.stop
  }

  Signal.trap "INT",  show_stopper
  Signal.trap "TERM", show_stopper

  # TLS connections take forever and a day
  # (compared to non-TLS connections) to estabilish.
  EM.add_timer(8, show_stopper)
end
