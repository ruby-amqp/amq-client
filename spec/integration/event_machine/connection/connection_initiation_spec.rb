require "integration/event_machine/spec_helper"

EM.describe EventMachine do
  should 'have timers' do
    start = Time.now

    EM.add_timer(0.5){
      (Time.now-start).should.be.close 0.5, 0.1
      done
    }
  end

  should 'have periodic timers' do
    num = 0
    start = Time.now

    timer = EM.add_periodic_timer(0.5){
      if (num += 1) == 2
        (Time.now-start).should.be.close 1.0, 0.1
        EM.__send__ :cancel_timer, timer
        done
      end
    }
  end
end