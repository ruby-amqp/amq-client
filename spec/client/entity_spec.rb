# encoding: utf-8

require "spec_helper"
require "amq/client/entity"

describe AMQ::Client::Entity do
  subject do
    AMQ::Client::Entity.new(Object.new)
  end

  it "should maintain an associative array of callbacks" do
    subject.callbacks.should be_kind_of(Hash)
  end

  describe "#exec_callback" do
    it "should call given callback" do
      subject.callbacks[:init] = begin
        Proc.new do |*args, &block|
          @called = true
        end
      end

      subject.exec_callback(:init)
      @called.should be_true
    end

    it "should pass itself as the first argument" do
      subject.callbacks[:init] = begin
        Proc.new { |entity, *args| entity }
      end

      subject.exec_callback(:init).should eql(subject)
    end

    it "should pass arguments to the callback" do
      subject.callbacks[:init] = begin
        Proc.new { |entity, *args| args }
      end

      subject.exec_callback(:init, 1).should eql([1])
    end

    it "should pass block to the callback" do
      subject.callbacks[:init] = begin
        Proc.new { |*args, &block| block.call }
      end

      subject.exec_callback(:init) { "block" }.should eql("block")
    end
  end
end
