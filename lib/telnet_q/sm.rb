module TelnetQ
  module SM
    # Implements the state machine described in Section 7 of RFC 1143.
    #
    # NOTE: This code is awful, so consider this entire API private and subject
    # to change!
    class HisOptionState

      def initialize(options={}, &block)
        @state = :no
        @supported_proc = options[:supported_proc]
        @send_proc = options[:send_proc]
        @error_proc = options[:error_proc]
        @negotiated_proc = options[:negotiated_proc]
      end

      # Is he allowed to enable this option?
      def supported?
        !!@supported_proc.call
      end

      attr_reader :state

      def state=(v)
        raise ArgumentError.new unless [:no, :yes, :wantno, :wantyes, :wantno_opposite, :wantyes_opposite].include?(v)
        old_state = @state
        @state = v
        if v != old_state
          if v == :yes
            negotiated(true)
          elsif v == :no
            negotiated(false)
          end
        end
        v
      end

      alias him state
      alias him= state

      def received(which)
        raise ArgumentError.new("invalid which=#{which.inspect}") unless [:will, :wont, :do, :dont].include?(which)
        send("received_#{which}")
      end

      # Received WILL for this option
      def received_will
        case state
        when :no
          if supported?
            self.state = :yes
            send_do
          else
            send_dont
          end
        when :yes
          # Ignore; already enabled
        when :wantno
          error("DONT answered by WILL.")
          self.state = :no
        when :wantno_opposite
          error("DONT answered by WILL.")
          self.state = :yes
        when :wantyes
          self.state = :yes
        when :wantyes_opposite
          self.state = :wantno
          send_dont
        else
          raise "BUG: Illegal state #{state.inspect}"
        end
      end

      def received_wont
        case state
        when :no
          # Ignore; already disabled
        when :yes
          self.state = :no
          send_dont
        when :wantno
          self.state = :no
        when :wantno_opposite
          self.state = :wantyes
          send_do
        when :wantyes
          self.state = :no
        when :wantyes_opposite
          self.state = :no
        else
          raise "BUG: Illegal state #{state.inspect}"
        end
      end

      # If we decide to ask him to enable
      def ask_enable
        case state
        when :no
          self.state = :wantyes
          send_do
        when :yes
          error("Already enabled.")
        when :wantno
          self.state = :wantno_opposite
        when :wantno_opposite
          error("Already queued an enable request.")
        when :wantyes
          error("Already negotiating for enable.")
        when :wantyes_opposite
          self.state = :wantyes
        else
          raise "BUG: Illegal state #{state.inspect}"
        end
      end

      def ask_disable
        case state
        when :no
          error("Already disabled.")
        when :yes
          self.state = :wantno
          send_dont
        when :wantno
          error("Already negotiating for disable.")
        when :wantno_opposite
          self.state = :wantno
        when :wantyes
          self.state = :wantyes_opposite
        when :wantyes_opposite
          error("Already queued a disable request.")
        else
          raise "BUG: Illegal state #{state.inspect}"
        end
      end

      def send_do; send_option(:do); end
      def send_dont; send_option(:dont); end

      def send_option(cmd)
        raise ArgumentError.new("invalid send-option #{cmd.inspect}") unless [:will, :wont, :do, :dont].include?(cmd)
        @send_proc.call(cmd)
      end

      def error(msg)
        @error_proc.call(msg)
      end

      def negotiated(enabled)
        @negotiated_proc.call(enabled)
      end
    end

    # Same, but for negotiating our options
    class MyOptionState < HisOptionState
      def send_will; send_option(:will); end
      def send_wont; send_option(:wont); end
      alias send_do send_will
      alias send_dont send_wont

      alias received_do received_will
      alias received_dont received_wont

      alias us state
      alias us= state=
    end
  end
end
