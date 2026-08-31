# src/vt/parser.cr
class VT::Parser
  @state             : St
  @intermediates     : StaticArray(UInt8, 8)
  @intermediates_len : Int32
  @params            : StaticArray(Parameter, 64)
  @params_len        : Int32
  @ignore            : Bool
  @handler           : Handler

  # Initializes a new Paul Williams state machine that dispatches events
  # to the provided `handler`.
  def initialize(@handler : Handler)
    @state             = St::Gnd
    @intermediates     = StaticArray(UInt8, 8).new(0_u8)
    @intermediates_len = 0
    @params            = StaticArray(Parameter, 64).new(Parameter.new)
    @params_len        = 0
    @ignore            = false
  end

  # Returns `true` if the state machine is currently in the ground state.
  def idle? : Bool
    @state == St::Gnd
  end

  # Parses a slice of bytes, synchronously dispatching events to the handler.
  def parse(bytes : Bytes) : Nil
    bytes.each do |char|
      advance(char)
    end
  end

  # Parses a UTF-8 string by inspecting its underlying bytes.
  def parse(str : String) : Nil
    parse(str.to_slice)
  end

  # Consumes from an IO stream until EOF, parsing byte chunks as they arrive.
  # The default chunk buffer size is 4096 bytes.
  def parse(io : IO, buffer_size : Int32 = 4096) : Nil
    buffer = Bytes.new(buffer_size)
    while (bytes_read = io.read(buffer)) > 0
      parse(buffer[0, bytes_read])
    end
  end

  # Forcefully resets the parser back to the ground state and clears all
  # intermediate and parameter state.
  def reset
    @state             = St::Gnd
    @intermediates_len = 0
    @params_len        = 0
    @ignore            = false
  end

  private def advance(char : UInt8)
    transition = Internal::TABLE[@state.value][char]
    action     = Act.new(transition >> 4)
    next_state = St.new(transition & 0x0F)

    if @state != next_state
      exit_action(@state)
    end

    perform_action(action, char)

    if @state != next_state
      enter_action(next_state)
      @state = next_state
    end
  end

  private def exit_action(state : St)
    case state
    when St::OscStr
      @handler.osc_end
    when St::SosStr
      @handler.sos_end
    when St::PmStr
      @handler.pm_end
    when St::ApcStr
      @handler.apc_end
    when St::DcsPass
      @handler.unhook
    else
    end
  end

  private def enter_action(state : St)
    case state
    when St::OscStr
      @handler.osc_start
    when St::SosStr
      @handler.sos_start
    when St::PmStr
      @handler.pm_start
    when St::ApcStr
      @handler.apc_start
    else
    end
  end

  private def perform_action(action : Act, char : UInt8)
    case action
    when Act::Prn
      @handler.print(char)
    when Act::Exec
      @handler.execute(char)
    when Act::Clr
      @intermediates_len = 0
      @params_len        = 0
      @ignore            = false
      @handler.clear
    when Act::Coll
      if @intermediates_len < 8
        @intermediates[@intermediates_len] = char
        @intermediates_len += 1
      else
        @ignore = true
      end
      @handler.collect(char)
    when Act::Prm
      if @ignore
        @handler.param(char)
      else
        if char == 0x3B
          if @params_len == 0
            @params[0] = Parameter.new(-1, false)
            @params[1] = Parameter.new(-1, false)
            @params_len = 2
          elsif @params_len < 64
            @params[@params_len] = Parameter.new(-1, false)
            @params_len += 1
          else
            @ignore = true
          end
        elsif char == 0x3A
          if @params_len == 0
            @params[0] = Parameter.new(-1, false)
            @params[1] = Parameter.new(-1, true)
            @params_len = 2
          elsif @params_len < 64
            @params[@params_len] = Parameter.new(-1, true)
            @params_len += 1
          else
            @ignore = true
          end
        else
          if @params_len == 0
            @params_len = 1
            @params[0] = Parameter.new(-1, false)
          end
          if @params_len <= 64
            val = @params[@params_len - 1].value
            val = 0 if val == -1
            sub = @params[@params_len - 1].sub

            if val <= (Int32::MAX - 9) // 10
              new_val = val * 10 + (char - 0x30).to_i
              @params[@params_len - 1] = Parameter.new(new_val, sub)
            else
              @params[@params_len - 1] = Parameter.new(Int32::MAX, sub)
            end
          end
        end
        @handler.param(char)
      end
    when Act::EscDisp
      @handler.esc_dispatch(char, @intermediates.to_slice[0, @intermediates_len], @ignore)
    when Act::CsiDisp
      @handler.csi_dispatch(char, @params.to_slice[0, @params_len], @intermediates.to_slice[0, @intermediates_len], @ignore)
    when Act::Hook
      @handler.hook(char, @params.to_slice[0, @params_len], @intermediates.to_slice[0, @intermediates_len], @ignore)
    when Act::Put
      @handler.put(char)
    when Act::StrPut
      case @state
      when St::OscStr
        @handler.osc_put(char)
      when St::SosStr
        @handler.sos_put(char)
      when St::PmStr
        @handler.pm_put(char)
      when St::ApcStr
        @handler.apc_put(char)
      else
      end
    when Act::Ign, Act::None, Act::Unhk
    end
  end
end
