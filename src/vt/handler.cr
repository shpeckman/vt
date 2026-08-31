# src/vt/handler.cr
module VT
  module Handler
    # Fired when a printable character is encountered in the ground state.
    abstract def print(char : UInt8)

    # Fired when a C0 or C1 control character is encountered.
    abstract def execute(char : UInt8)

    # Fired at the beginning of a new escape sequence.
    abstract def clear

    # Fired when an intermediate character (e.g. `?`, `>`, `!`) is encountered
    # during an escape, CSI, or DCS sequence.
    abstract def collect(char : UInt8)

    # Fired when a parameter digit, semicolon (`;`), or colon (`:`) is encountered.
    abstract def param(char : UInt8)

    # Fired when a standard escape sequence is finalized.
    abstract def esc_dispatch(char : UInt8, intermediates : Slice(UInt8), ignore : Bool)

    # Fired when a Control Sequence Introducer (CSI) sequence is finalized.
    abstract def csi_dispatch(char : UInt8, params : Slice(Parameter), intermediates : Slice(UInt8), ignore : Bool)

    # Fired at the beginning of a Device Control String (DCS) payload.
    abstract def hook(char : UInt8, params : Slice(Parameter), intermediates : Slice(UInt8), ignore : Bool)

    # Fired for each byte in a DCS payload.
    abstract def put(char : UInt8)

    # Fired when a DCS payload is finalized.
    abstract def unhook

    # Fired at the beginning of an Operating System Command (OSC) payload.
    abstract def osc_start

    # Fired for each byte in an OSC payload.
    abstract def osc_put(char : UInt8)

    # Fired when an OSC payload is finalized.
    abstract def osc_end

    # Fired at the beginning of a Start of String (SOS) payload.
    abstract def sos_start

    # Fired for each byte in a SOS payload.
    abstract def sos_put(char : UInt8)

    # Fired when a SOS payload is finalized.
    abstract def sos_end

    # Fired at the beginning of a Privacy Message (PM) payload.
    abstract def pm_start

    # Fired for each byte in a PM payload.
    abstract def pm_put(char : UInt8)

    # Fired when a PM payload is finalized.
    abstract def pm_end

    # Fired at the beginning of an Application Program Command (APC) payload.
    abstract def apc_start

    # Fired for each byte in an APC payload.
    abstract def apc_put(char : UInt8)

    # Fired when an APC payload is finalized.
    abstract def apc_end
  end

  module BaseHandler
    include Handler

    # :inherit:
    def print(char : UInt8)
    end

    # :inherit:
    def execute(char : UInt8)
    end

    # :inherit:
    def clear
    end

    # :inherit:
    def collect(char : UInt8)
    end

    # :inherit:
    def param(char : UInt8)
    end

    # :inherit:
    def esc_dispatch(char : UInt8, intermediates : Slice(UInt8), ignore : Bool)
    end

    # :inherit:
    def csi_dispatch(char : UInt8, params : Slice(Parameter), intermediates : Slice(UInt8), ignore : Bool)
    end

    # :inherit:
    def hook(char : UInt8, params : Slice(Parameter), intermediates : Slice(UInt8), ignore : Bool)
    end

    # :inherit:
    def put(char : UInt8)
    end

    # :inherit:
    def unhook
    end

    # :inherit:
    def osc_start
    end

    # :inherit:
    def osc_put(char : UInt8)
    end

    # :inherit:
    def osc_end
    end

    # :inherit:
    def sos_start
    end

    # :inherit:
    def sos_put(char : UInt8)
    end

    # :inherit:
    def sos_end
    end

    # :inherit:
    def pm_start
    end

    # :inherit:
    def pm_put(char : UInt8)
    end

    # :inherit:
    def pm_end
    end

    # :inherit:
    def apc_start
    end

    # :inherit:
    def apc_put(char : UInt8)
    end

    # :inherit:
    def apc_end
    end
  end

  module BufferedHandler
    include BaseHandler
    include UTF8

    # The maximum size in bytes that the handler will buffer for a single
    # string payload before truncating and setting the `overflow` flag to true.
    # Defaults to 1MB to prevent memory exhaustion.
    property payload_limit : Int32 = 1_048_576

    @string_buffer     : String::Builder  = String::Builder.new
    @dcs_char          : UInt8            = 0_u8
    @dcs_params        : Array(Parameter) = Array(Parameter).new
    @dcs_intermediates : Array(UInt8)     = Array(UInt8).new
    @dcs_ignore        : Bool             = false
    @payload_size      : Int32            = 0
    @payload_overflow  : Bool             = false

    # Fired when a completely decoded UTF-8 character is encountered in the
    # ground state.
    abstract def print(char : Char)

    # Fired with a completely assembled string payload after an OSC sequence completes.
    abstract def osc_dispatch(payload : String, overflow : Bool)

    # Fired with a completely assembled string payload after a DCS sequence completes.
    abstract def dcs_dispatch(char : UInt8, params : Array(Parameter), intermediates : Array(UInt8), ignore : Bool, payload : String, overflow : Bool)

    # Fired with a completely assembled string payload after a SOS sequence completes.
    abstract def sos_dispatch(payload : String, overflow : Bool)

    # Fired with a completely assembled string payload after a PM sequence completes.
    abstract def pm_dispatch(payload : String, overflow : Bool)

    # Fired with a completely assembled string payload after an APC sequence completes.
    abstract def apc_dispatch(payload : String, overflow : Bool)

    # :inherit:
    def print(char : UInt8)
      decoded = decode_byte(char)
      print(decoded) if decoded
    end

    # :inherit:
    def hook(char : UInt8, params : Slice(Parameter), intermediates : Slice(UInt8), ignore : Bool)
      @dcs_char          = char
      @dcs_params        = params.to_a
      @dcs_intermediates = intermediates.to_a
      @dcs_ignore        = ignore
      reset_payload
    end

    # :inherit:
    def put(char : UInt8)
      append_payload(char)
    end

    # :inherit:
    def unhook
      dcs_dispatch(@dcs_char, @dcs_params, @dcs_intermediates, @dcs_ignore, @string_buffer.to_s, @payload_overflow)
      @string_buffer = String::Builder.new
    end

    # :inherit:
    def osc_start
      reset_payload
    end

    # :inherit:
    def osc_put(char : UInt8)
      append_payload(char)
    end

    # :inherit:
    def osc_end
      osc_dispatch(@string_buffer.to_s, @payload_overflow)
      @string_buffer = String::Builder.new
    end

    # :inherit:
    def sos_start
      reset_payload
    end

    # :inherit:
    def sos_put(char : UInt8)
      append_payload(char)
    end

    # :inherit:
    def sos_end
      sos_dispatch(@string_buffer.to_s, @payload_overflow)
      @string_buffer = String::Builder.new
    end

    # :inherit:
    def pm_start
      reset_payload
    end

    # :inherit:
    def pm_put(char : UInt8)
      append_payload(char)
    end

    # :inherit:
    def pm_end
      pm_dispatch(@string_buffer.to_s, @payload_overflow)
      @string_buffer = String::Builder.new
    end

    # :inherit:
    def apc_start
      reset_payload
    end

    # :inherit:
    def apc_put(char : UInt8)
      append_payload(char)
    end

    # :inherit:
    def apc_end
      apc_dispatch(@string_buffer.to_s, @payload_overflow)
      @string_buffer = String::Builder.new
    end

    private def reset_payload : Nil
      @string_buffer    = String::Builder.new
      @payload_size     = 0
      @payload_overflow = false
    end

    private def append_payload(char : UInt8) : Nil
      return if @payload_overflow

      @payload_size += 1

      if @payload_size > @payload_limit
        @payload_overflow = true
        return
      end

      decoded = decode_byte(char)
      @string_buffer << decoded if decoded
    end
  end
end
