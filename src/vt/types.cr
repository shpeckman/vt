# src/vt/types.cr
module VT
  private enum St : UInt8
    Gnd     = 0
    Esc
    EscInt
    CsiEnt
    CsiPrm
    CsiInt
    CsiIgn
    DcsEnt
    DcsPrm
    DcsInt
    DcsPass
    DcsIgn
    OscStr
    SosStr
    PmStr
    ApcStr
  end

  private enum Act : UInt8
    None    = 0
    Ign
    Prn
    Exec
    Clr
    Coll
    Prm
    EscDisp
    CsiDisp
    Hook
    Put
    Unhk
    StrPut
  end

  # Represents common C0 control codes, typically dispatched to the
  # `execute` callback.
  enum Control : UInt8
    NUL = 0x00
    BEL = 0x07
    BS  = 0x08
    HT  = 0x09
    LF  = 0x0A
    VT  = 0x0B
    FF  = 0x0C
    CR  = 0x0D
    ESC = 0x1B
  end

  # Represents a numeric parameter extracted from a CSI or DCS sequence.
  struct Parameter
    # The integer value of the parameter. A value of `-1` indicates
    # that the parameter was omitted by the sender.
    property value : Int32

    # Indicates whether this parameter is a sub-parameter, meaning it
    # was delimited by a colon (`:`) rather than a semicolon (`;`).
    property sub : Bool

    # Initializes a new Parameter with an optional value and sub flag.
    def initialize(@value : Int32 = -1, @sub : Bool = false)
    end

    # Returns true if the parameter was omitted in the escape sequence.
    def empty? : Bool
      @value == -1
    end

    # Returns the parameter's integer value, or the provided `default`
    # if the parameter is empty.
    def fetch(default : Int32) : Int32
      empty? ? default : @value
    end
  end
end
