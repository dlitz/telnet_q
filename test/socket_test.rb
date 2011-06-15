require 'test_helper'
require 'socket'

class SocketTest < Test::Unit::TestCase
  class TQSocketQ < TelnetQ::SocketQ
    def initialize(test_events, *args)
      @test_events = test_events
      super(*args)
    end

    attr_accessor :name

    def received_message(verb, option)
      @test_events << "#{name}: Received #{verb.to_s.upcase} #{option.inspect}"
      super
    end

    def send_message(verb, option)
      @test_events << "#{name}: Sent #{verb.to_s.upcase} #{option.inspect}"
      super
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
    alice_socket, bob_socket = Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)

    events = []

    alice = TQSocketQ.new(events, alice_socket, :us => [], :him => [0])
    bob = TQSocketQ.new(events, bob_socket, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"

    alice.start
    bob.start

    until events.length >= 5
      rr, ww, ee = select([alice_socket, bob_socket], nil, nil)
      if rr.include?(alice_socket)
        alice.received_raw_message(alice_socket.read(3))
      end
      if rr.include?(bob_socket)
        bob.received_raw_message(bob_socket.read(3))
      end
    end

    assert_equal [
     "alice: Sent DO 0",
     "bob: Received DO 0",
     "bob: Sent WONT 0",
     "alice: Received WONT 0",
     "alice: They disabled option 0",
    ], events
  ensure
    alice_socket.close if alice_socket
    bob_socket.close if bob_socket
  end

  def test_option_not_supported_us
    alice_socket, bob_socket = Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)

    events = []

    alice = TQSocketQ.new(events, alice_socket, :us => [0], :him => [])
    bob = TQSocketQ.new(events, bob_socket, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"

    alice.start
    bob.start

    until events.length >= 5
      rr, ww, ee = select([alice_socket, bob_socket], nil, nil)
      if rr.include?(alice_socket)
        alice.received_raw_message(alice_socket.read(3))
      end
      if rr.include?(bob_socket)
        bob.received_raw_message(bob_socket.read(3))
      end
    end

    assert_equal [
     "alice: Sent WILL 0",
     "bob: Received WILL 0",
     "bob: Sent DONT 0",
     "alice: Received DONT 0",
     "alice: We disabled option 0",
    ], events
  ensure
    alice_socket.close if alice_socket
    bob_socket.close if bob_socket
  end

  def test_option_supported_him
    alice_socket, bob_socket = Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)

    events = []

    alice = TQSocketQ.new(events, alice_socket, :us => [], :him => [3])
    bob = TQSocketQ.new(events, bob_socket, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"

    alice.start
    bob.start

    until events.length >= 5
      rr, ww, ee = select([alice_socket, bob_socket], nil, nil)
      if rr.include?(alice_socket)
        alice.received_raw_message(alice_socket.read(3))
      end
      if rr.include?(bob_socket)
        bob.received_raw_message(bob_socket.read(3))
      end
    end

    assert_equal [
      "alice: Sent DO 3",
      "bob: Received DO 3",
      "bob: We enabled option 3",
      "bob: Sent WILL 3",
      "alice: Received WILL 3",
      "alice: They enabled option 3",
    ], events
  ensure
    alice_socket.close if alice_socket
    bob_socket.close if bob_socket
  end

  def test_option_supported_us
    alice_socket, bob_socket = Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)

    events = []

    alice = TQSocketQ.new(events, alice_socket, :us => [3], :him => [])
    bob = TQSocketQ.new(events, bob_socket, :us => [], :him => [])
    alice.name = "alice"
    bob.name = "bob"

    alice.start
    bob.start

    until events.length >= 5
      rr, ww, ee = select([alice_socket, bob_socket], nil, nil)
      if rr.include?(alice_socket)
        alice.received_raw_message(alice_socket.read(3))
      end
      if rr.include?(bob_socket)
        bob.received_raw_message(bob_socket.read(3))
      end
    end

    assert_equal [
      "alice: Sent WILL 3",
      "bob: Received WILL 3",
      "bob: They enabled option 3",
      "bob: Sent DO 3",
      "alice: Received DO 3",
      "alice: We enabled option 3",
    ], events
  ensure
    alice_socket.close if alice_socket
    bob_socket.close if bob_socket
  end
end

