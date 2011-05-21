# encoding: utf-8

require "spec_helper"
require "amq/client/entity"

describe AMQ::Client::Entity do
  let(:klazz) do
    Class.new do
      include AMQ::Client::Entity
    end
  end


  subject do
    klazz.new(Object.new)
  end

  it "should maintain an associative array of callbacks" do
    subject.callbacks.should be_kind_of(Hash)
  end

  describe "#has_callback?" do
    it "should return true if entity has at least one callback with given name" do
      subject.define_callback(:init, proc {})
      subject.has_callback?(:init).should be_true
    end

    it "should return false if entity doesn't have callbacks with given name" do
      subject.has_callback?(:init).should be_false
    end
  end

  describe "#exec_callback" do
    it "executes callback for given event" do
      proc = Proc.new { |*args, &block|
        @called = true
      }

      expect {
        subject.define_callback(:init, proc)
        subject.define_callback :init do
          @called2 = true
        end
      }.to change(subject.callbacks, :size).from(0).to(1)

      subject.callbacks[:init].size.should == 2

      subject.exec_callback(:init)

      @called.should be_true
      @called2.should be_true
    end


    it "should pass arguments to the callback" do
      f = Proc.new { |*args| args.first }
      subject.define_callback :init, f

      subject.exec_callback(:init, 1).should eql([f])
    end
  end
end
