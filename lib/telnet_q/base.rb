require 'set'

module TelnetQ
  # This class implements RFC 1143 - The Q Method of implementing TELNET option negotiation.
  #
  # There are two sides to the conversation: "us" and "him".  "us" refers to
  # the local party; "him" refers to the remote party. (This is the terminology
  # used in the RFC.)
  #
  # Telnet options are integers between 0 and 255.  The current list of options
  # is available at: http://www.iana.org/assignments/telnet-options
  #
  # Options:
  #
  # [:us]
  #   The list of options the local party should initially enable.  When the
  #   connection is established, the local party sends a WILL request for each
  #   of these options.  Note that if the remote party sends DONT in response
  #   to our request, the option will remain disabled.
  # [:him]
  #   The list of options we want the remote party should initially enable.
  #   When the connection is established, the local party sends a DO request
  #   for each of these options.  Note that if the remote party sends WONT
  #   in response to our request, the option will remain disabled.
  #
  # Example usage:
  #
  #   TelnetQ::Base.new(:us => [0,3], :him => [0,1,3])
  #
  class Base
    def initialize(options={})
      @state_machines = {
        :us => {},
        :him => {},
      }
      @supported_options = {
        :us => Set.new(options[:us] || []),
        :him => Set.new(options[:him].uniq || []),
      }
    end

    def start
      initial_requests
    end

    def inspect
      us = @state_machines[:us].keys.sort.map{|opt| "#{opt}:#{@state_machines[:us][opt].state}"}.join(" ")
      him = @state_machines[:him].keys.sort.map{|opt| "#{opt}:#{@state_machines[:him][opt].state}"}.join(" ")
      "#<#{self.class.name} us(#{us}) him(#{him})>"
    end

    # Invoke this when a TELNET negotiation message is received.
    #
    # Example usage:
    #   tq = TelnetQ::Base.new(...)
    #   tq.received_message(:do, 0)       # Remote party requesting that we enable binary transmission on our side
    #   tq.received_message(:will, 0)     # Remote party requesting that to enable binary transmission on his side.
    def received_message(verb, option)
      case verb
      when :do, :dont
        party = :us
      when :will, :wont
        party = :him
      else
        raise ArgumentError.new("invalid verb #{verb.inspect}")
      end
      sm = state_machine(party, option)
      sm.received(verb)
      nil
    end

    # Check whether the option is currently enabled
    def enabled?(party, option)
      sm = state_machine(party, option)
      sm.state == :yes
    end

    # Ask the specified party enable this option.
    #
    # party may be one of :us or :them.
    def request(party, option)
      sm = state_machine(party, option)
      @supported_options[party] << option
      sm.ask_enable unless sm.state == :yes
      nil
    end

    # Ask the specified party to disable this option.
    #
    # party may be one of :us or :them.
    def forbid(party, option)
      sm = state_machine(party, option)
      @supported_options[party].delete(option)
      sm.ask_disable unless sm.state == :no
      nil
    end

    protected

    # Callback invoked when the remote party requests that a currently-disabled
    # option be enabled.
    #
    # The "party" parameter is as follows:
    # [:us]
    #   Received a request for the local party to enable the option. (Remote sent DO).
    # [:him]
    #   Received a request for the remote party enable the option. (Remote sent WILL).
    #
    # Return true if we allow the change, or false if we forbid it.
    #
    # You may override this in your subclass.
    def option_supported?(party, option)
      @supported_options[party].include?(option)
    end

    # Callback invoked when the specified option has been negotiated.
    #
    # Override this in your subclass.
    def option_negotiated(party, option, enabled)
      #puts "#{party == :us ? "We" : "He"} #{enabled ? "enabled" : "disabled"} option #{option}"
      nil
    end

    # Callback: Send the specified message to the remote party.
    #
    # Override this in your subclass.
    def send_message(verb, option)
      #puts "SEND #{verb.to_s.upcase} #{option.inspect}"
      nil
    end

    # Callback: Invoked when there is an error negotiating the specified option.
    #
    # Override this in your subclass.
    def error(msg, party, option)
      $stderr.puts "Error negotiating option #{party}#{option}: #{msg}"
      nil
    end

    private

    def state_machine(party, option)
      party = parse_party(party)
      option = parse_option(option)

      unless @state_machines[party][option]
        case party
        when :him
          sm = SM::HisOptionState.new(:supported_proc => lambda{ option_supported?(:him, option) },
                                      :send_proc => lambda{ |verb| send_message(verb, option) },
                                      :negotiated_proc => lambda{ |enabled| option_negotiated(:him, option, enabled) },
                                      :error_proc => lambda{ |msg| error(msg, :him, option) })
          @state_machines[party][option] = sm
        when :us
          sm = SM::MyOptionState.new(:supported_proc => lambda{ option_supported?(:us, option) },
                                     :send_proc => lambda{ |verb| send_message(verb, option) },
                                     :negotiated_proc => lambda{ |enabled| option_negotiated(:us, option, enabled) },
                                     :error_proc => lambda{ |msg| error(msg, :us, option) })
          @state_machines[party][option] = sm
        else
          raise "BUG"
        end
      end
      @state_machines[party][option]
    end

    def parse_option(option)
      raise TypeError.new("option must be an integer") unless option.is_a?(Integer)
      option
    end

    def parse_party(party)
      raise ArgumentError.new("party must be :us or :him") unless [:us, :him].include?(party)
      party
    end

    def initial_requests
      # Set the initial options
      [:us, :him].each do |party|
        @supported_options[party].each do |option|
          request(party, option)
        end
      end
    end
  end
end
