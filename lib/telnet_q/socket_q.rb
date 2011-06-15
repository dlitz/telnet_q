require 'telnet_q/base'

module TelnetQ
  class SocketQ < Base

    VERB_NAMES = {
      251 => :will,
      252 => :wont,
      253 => :do,
      254 => :dont,
    }.freeze

    VERB_NUMS = VERB_NAMES.invert.freeze

    def initialize(connection, options={})
      @connection = connection
      super(options)
    end

    # Invoke this when a TELNET negotiation message is received.
    #
    # Example usage:
    #   sq = TelnetQ::SocketQ.new(connection, ...)
    #   sq.received_raw_message("\377\375\000")       # Remote party requesting that we enable binary transmission on our side
    #   sq.received_raw_message("\377\373\000")     # Remote party requesting that to enable binary transmission on his side.
    def received_raw_message(raw)
      verb, option = parse_raw_telnet_option_message(raw)
      received_message(verb, option)
    end

    protected

      def send_message(verb, option)
        send_raw_message(generate_raw_telnet_option_message(verb, option))
      end

      def send_raw_message(raw)
        @connection.write(raw)
      end

      # Translate e.g. "\377\375\000" -> [:do, 0]
      def parse_raw_telnet_option_message(raw)
        iac, v, option = raw.unpack("CCC")
        verb = VERB_NAMES[v]
        raise ArgumentError.new("illegal option") unless raw.length == 3 and iac == 255 and verb
        [verb, option]
      end

      # Translate e.g. [:do, 0] -> "\377\375\000"
      def generate_raw_telnet_option_message(verb, option)
        vn = VERB_NUMS[verb]
        raise ArgumentError.new("unsupported verb: #{verb.inspect}") unless vn
        raise ArgumentError.new("illegal option: #{option.inspect}") unless option.is_a?(Integer) and (0..255).include?(option)
        [255, vn, option].pack("CCC")
      end
  end
end
