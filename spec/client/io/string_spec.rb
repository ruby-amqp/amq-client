# encoding: utf-8

require "spec_helper"
require "amq/client/io/string"

describe AMQ::Client::StringAdapter do
  subject do
    Class.new { include AMQ::Client::StringAdapter }.new
  end
end
