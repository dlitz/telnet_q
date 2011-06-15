require 'test_helper'

class BaseTest < Test::Unit::TestCase
  class TQBase < TelnetQ::Base
    def initialize(test_events, *args)
      @test_events = test_events
      super(*args)
    end

    attr_accessor :other
    attr_accessor :name

    def received_message(verb, option)
      @test_events << "#{name}: Received #{verb.to_s.upcase} #{option.inspect}"
      super
    end

    def send_message(verb, option)
      @test_events << "#{name}: Sent #{verb.to_s.upcase} #{option.inspect}"
      @other.received_message(verb, option)
    end

    # Always allow option 3 (for both parties)
    def option_supported?(party, option)
      (option == 3) or super
    end

    def option_negotiated(party, option, enabled)
      @test_events << "#{name}: #{party == :us ? "We" : "They"} #{enabled ? "enabled" : "disabled"} option #{option}"
    end
  end

  def test_option_not_supported_him
    events = []

    alice = TQBase.new(events, :us => [], :him => [0])
    bob = TQBase.new(events, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"
    alice.other = bob
    bob.other = alice

    alice.start
    bob.start

    assert_equal [
     "alice: Sent DO 0",
     "bob: Received DO 0",
     "bob: Sent WONT 0",
     "alice: Received WONT 0",
     "alice: They disabled option 0",
    ], events
  end

  def test_option_not_supported_us
    events = []

    alice = TQBase.new(events, :us => [0], :him => [])
    bob = TQBase.new(events, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"
    alice.other = bob
    bob.other = alice

    alice.start
    bob.start

    assert_equal [
     "alice: Sent WILL 0",
     "bob: Received WILL 0",
     "bob: Sent DONT 0",
     "alice: Received DONT 0",
     "alice: We disabled option 0",
    ], events
  end

  def test_option_supported_him
    events = []

    alice = TQBase.new(events, :us => [], :him => [3])
    bob = TQBase.new(events, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"
    alice.other = bob
    bob.other = alice

    alice.start
    bob.start

    assert_equal [
      "alice: Sent DO 3",
      "bob: Received DO 3",
      "bob: We enabled option 3",
      "bob: Sent WILL 3",
      "alice: Received WILL 3",
      "alice: They enabled option 3",
    ], events
  end

  def test_option_supported_us
    events = []

    alice = TQBase.new(events, :us => [3], :him => [])
    bob = TQBase.new(events, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"
    alice.other = bob
    bob.other = alice

    alice.start
    bob.start

    assert_equal [
      "alice: Sent WILL 3",
      "bob: Received WILL 3",
      "bob: They enabled option 3",
      "bob: Sent DO 3",
      "alice: Received DO 3",
      "alice: We enabled option 3",
    ], events
  end
end
