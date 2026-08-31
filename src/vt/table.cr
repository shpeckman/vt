# src/vt/table.cr
require "./types"

module VT::Internal
  private def self.set_trans(table : Array(Array(UInt8)), state : VT::St, range : Int32 | Range(Int32, Int32), action : VT::Act, next_state : VT::St)
    st     = state.value.to_i
    packed = (action.value.to_u8 << 4) | next_state.value.to_u8
    if range.is_a?(Int32)
      table[st][range] = packed
    else
      range.each { |c| table[st][c] = packed }
    end
  end

  private def self.set_anywhere(table : Array(Array(UInt8)), range : Int32 | Range(Int32, Int32), action : VT::Act, next_state : VT::St)
    16.times do |s|
      set_trans(table, VT::St.new(s.to_u8), range, action, next_state)
    end
  end

  macro build_transitions(table, config)
    {% for row in config %}
      set_trans({{table}}, VT::St::{{row[0].id}}, {{row[1]}}, VT::Act::{{row[2].id}}, VT::St::{{row[3].id}})
    {% end %}
  end

  private def self.build_table
    temp_table = Array(Array(UInt8)).new(16) { Array(UInt8).new(256, 0_u8) }

    set_anywhere(temp_table, 0x18, VT::Act::Exec, VT::St::Gnd)
    set_anywhere(temp_table, 0x1A, VT::Act::Exec, VT::St::Gnd)
    set_anywhere(temp_table, 0x1B, VT::Act::Clr, VT::St::Esc)

    build_transitions(temp_table, {
      {Gnd,     0x00..0x17, Exec,    Gnd},
      {Gnd,     0x19,       Exec,    Gnd},
      {Gnd,     0x1C..0x1F, Exec,    Gnd},
      {Gnd,     0x20..0xFF, Prn,     Gnd},
      {Esc,     0x00..0x17, Exec,    Esc},
      {Esc,     0x19,       Exec,    Esc},
      {Esc,     0x1C..0x1F, Exec,    Esc},
      {Esc,     0x7F,       Ign,     Esc},
      {Esc,     0x80..0xFF, Prn,     Gnd},
      {Esc,     0x20..0x2F, Coll,    EscInt},
      {Esc,     0x30..0x4F, EscDisp, Gnd},
      {Esc,     0x51..0x57, EscDisp, Gnd},
      {Esc,     0x59,       EscDisp, Gnd},
      {Esc,     0x5A,       EscDisp, Gnd},
      {Esc,     0x5C,       EscDisp, Gnd},
      {Esc,     0x60..0x7E, EscDisp, Gnd},
      {Esc,     0x50,       None,    DcsEnt},
      {Esc,     0x5D,       None,    OscStr},
      {Esc,     0x5B,       None,    CsiEnt},
      {Esc,     0x58,       None,    SosStr},
      {Esc,     0x5E,       None,    PmStr},
      {Esc,     0x5F,       None,    ApcStr},
      {EscInt,  0x00..0x17, Exec,    EscInt},
      {EscInt,  0x19,       Exec,    EscInt},
      {EscInt,  0x1C..0x1F, Exec,    EscInt},
      {EscInt,  0x20..0x2F, Coll,    EscInt},
      {EscInt,  0x7F,       Ign,     EscInt},
      {EscInt,  0x80..0xFF, Prn,     Gnd},
      {EscInt,  0x30..0x7E, EscDisp, Gnd},
      {CsiEnt,  0x00..0x17, Exec,    CsiEnt},
      {CsiEnt,  0x19,       Exec,    CsiEnt},
      {CsiEnt,  0x1C..0x1F, Exec,    CsiEnt},
      {CsiEnt,  0x7F,       Ign,     CsiEnt},
      {CsiEnt,  0x80..0xFF, Prn,     Gnd},
      {CsiEnt,  0x20..0x2F, Coll,    CsiInt},
      {CsiEnt,  0x30..0x39, Prm,     CsiPrm},
      {CsiEnt,  0x3A,       Prm,     CsiPrm},
      {CsiEnt,  0x3B,       Prm,     CsiPrm},
      {CsiEnt,  0x3C..0x3F, Coll,    CsiPrm},
      {CsiEnt,  0x40..0x7E, CsiDisp, Gnd},
      {CsiPrm,  0x00..0x17, Exec,    CsiPrm},
      {CsiPrm,  0x19,       Exec,    CsiPrm},
      {CsiPrm,  0x1C..0x1F, Exec,    CsiPrm},
      {CsiPrm,  0x30..0x39, Prm,     CsiPrm},
      {CsiPrm,  0x3A,       Prm,     CsiPrm},
      {CsiPrm,  0x3B,       Prm,     CsiPrm},
      {CsiPrm,  0x7F,       Ign,     CsiPrm},
      {CsiPrm,  0x80..0xFF, Prn,     Gnd},
      {CsiPrm,  0x3C..0x3F, None,    CsiIgn},
      {CsiPrm,  0x20..0x2F, Coll,    CsiInt},
      {CsiPrm,  0x40..0x7E, CsiDisp, Gnd},
      {CsiInt,  0x00..0x17, Exec,    CsiInt},
      {CsiInt,  0x19,       Exec,    CsiInt},
      {CsiInt,  0x1C..0x1F, Exec,    CsiInt},
      {CsiInt,  0x20..0x2F, Coll,    CsiInt},
      {CsiInt,  0x7F,       Ign,     CsiInt},
      {CsiInt,  0x80..0xFF, Prn,     Gnd},
      {CsiInt,  0x30..0x3F, None,    CsiIgn},
      {CsiInt,  0x40..0x7E, CsiDisp, Gnd},
      {CsiIgn,  0x00..0x17, Exec,    CsiIgn},
      {CsiIgn,  0x19,       Exec,    CsiIgn},
      {CsiIgn,  0x1C..0x1F, Exec,    CsiIgn},
      {CsiIgn,  0x20..0x3F, Ign,     CsiIgn},
      {CsiIgn,  0x7F,       Ign,     CsiIgn},
      {CsiIgn,  0x80..0xFF, Prn,     Gnd},
      {CsiIgn,  0x40..0x7E, None,    Gnd},
      {DcsEnt,  0x00..0x17, Ign,     DcsEnt},
      {DcsEnt,  0x19,       Ign,     DcsEnt},
      {DcsEnt,  0x1C..0x1F, Ign,     DcsEnt},
      {DcsEnt,  0x7F,       Ign,     DcsEnt},
      {DcsEnt,  0x80..0xFF, Prn,     Gnd},
      {DcsEnt,  0x20..0x2F, Coll,    DcsInt},
      {DcsEnt,  0x30..0x39, Prm,     DcsPrm},
      {DcsEnt,  0x3A,       Prm,     DcsPrm},
      {DcsEnt,  0x3B,       Prm,     DcsPrm},
      {DcsEnt,  0x3C..0x3F, Coll,    DcsPrm},
      {DcsEnt,  0x40..0x7E, Hook,    DcsPass},
      {DcsPrm,  0x00..0x17, Ign,     DcsPrm},
      {DcsPrm,  0x19,       Ign,     DcsPrm},
      {DcsPrm,  0x1C..0x1F, Ign,     DcsPrm},
      {DcsPrm,  0x30..0x39, Prm,     DcsPrm},
      {DcsPrm,  0x3A,       Prm,     DcsPrm},
      {DcsPrm,  0x3B,       Prm,     DcsPrm},
      {DcsPrm,  0x7F,       Ign,     DcsPrm},
      {DcsPrm,  0x80..0xFF, Prn,     Gnd},
      {DcsPrm,  0x3C..0x3F, None,    DcsIgn},
      {DcsPrm,  0x20..0x2F, Coll,    DcsInt},
      {DcsPrm,  0x40..0x7E, Hook,    DcsPass},
      {DcsInt,  0x00..0x17, Ign,     DcsInt},
      {DcsInt,  0x19,       Ign,     DcsInt},
      {DcsInt,  0x1C..0x1F, Ign,     DcsInt},
      {DcsInt,  0x20..0x2F, Coll,    DcsInt},
      {DcsInt,  0x7F,       Ign,     DcsInt},
      {DcsInt,  0x80..0xFF, Prn,     Gnd},
      {DcsInt,  0x30..0x3F, None,    DcsIgn},
      {DcsInt,  0x40..0x7E, Hook,    DcsPass},
      {DcsPass, 0x00..0x17, Put,     DcsPass},
      {DcsPass, 0x19,       Put,     DcsPass},
      {DcsPass, 0x1C..0x1F, Put,     DcsPass},
      {DcsPass, 0x20..0x7E, Put,     DcsPass},
      {DcsPass, 0x7F,       Ign,     DcsPass},
      {DcsPass, 0x80..0xFF, Put,     DcsPass},
      {DcsIgn,  0x00..0x17, Ign,     DcsIgn},
      {DcsIgn,  0x19,       Ign,     DcsIgn},
      {DcsIgn,  0x1C..0x1F, Ign,     DcsIgn},
      {DcsIgn,  0x20..0x7F, Ign,     DcsIgn},
      {DcsIgn,  0x80..0xFF, Ign,     DcsIgn},
      {OscStr,  0x00..0x17, Ign,     OscStr},
      {OscStr,  0x19,       Ign,     OscStr},
      {OscStr,  0x1C..0x1F, Ign,     OscStr},
      {OscStr,  0x20..0xFF, StrPut,  OscStr},
      {OscStr,  0x07,       None,    Gnd},
      {SosStr,  0x00..0x17, Ign,     SosStr},
      {SosStr,  0x19,       Ign,     SosStr},
      {SosStr,  0x1C..0x1F, Ign,     SosStr},
      {SosStr,  0x20..0xFF, StrPut,  SosStr},
      {PmStr,   0x00..0x17, Ign,     PmStr},
      {PmStr,   0x19,       Ign,     PmStr},
      {PmStr,   0x1C..0x1F, Ign,     PmStr},
      {PmStr,   0x20..0xFF, StrPut,  PmStr},
      {ApcStr,  0x00..0x17, Ign,     ApcStr},
      {ApcStr,  0x19,       Ign,     ApcStr},
      {ApcStr,  0x1C..0x1F, Ign,     ApcStr},
      {ApcStr,  0x20..0xFF, StrPut,  ApcStr},
    })

    StaticArray(StaticArray(UInt8, 256), 16).new do |i|
      StaticArray(UInt8, 256).new do |j|
        temp_table[i][j]
      end
    end
  end

  TABLE = build_table
end
