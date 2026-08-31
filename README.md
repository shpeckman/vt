# vt

A fast, allocation-free ANSI/VT escape sequence parser for Crystal.  

`vt` implements the [Paul Williams DEC-compatible parser](https://vt100.net/emu/dec_ansi_parser) as a packed, table-driven state machine.  
It consumes raw bytes and dispatches events to a handler you provide.  
It does not interpret sequences, maintain a screen buffer, or make policy decisions about what a sequence means — that is your terminal's job.  
This shard turns a byte stream into structured events.

## Features

- Full Williams state machine: ground, escape, CSI, DCS, OSC, SOS, PM, APC.
- Packed 16 × 256 transition table; one lookup and two nibble extractions per byte.
- Zero allocations in the parser hot path — parameters and intermediates live in `StaticArray`s.
- Sub-parameter support (`38:2:255:0:100`) with colon/semicolon distinction preserved.
- Streaming: parse arbitrarily split chunks, `Bytes`, `String`, or an `IO`.
- Optional buffered handler with streaming UTF-8 decoding and payload assembly.
- Payload size limits with an explicit overflow flag, so a hostile stream cannot exhaust memory.
- Declarative dispatch macros for routing CSI and DCS sequences.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  vt:
    github: shpeckman/vt
```

Then run:

```sh
shards install
```

Requires Crystal `>= 1.21.0`.

## Quick start

```crystal
require "vt"

class Logger
  include VT::BaseHandler

  def print(char : UInt8)
    STDOUT.write_byte(char)
  end

  def execute(char : UInt8)
    puts "\ncontrol: #{char}"
  end

  def csi_dispatch(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    return if ignore
    puts "\nCSI #{char.unsafe_chr} #{params.map(&.value)}"
  end
end

parser = VT::Parser.new(Logger.new)
parser.parse("\e[1;31mhello\e[0m\n")
```

## Parser

```crystal
parser = VT::Parser.new(handler)

parser.parse(bytes)                    # Bytes
parser.parse("\e[2J")                  # String, parsed as its UTF-8 bytes
parser.parse(io, buffer_size: 4096)    # drains the IO until EOF

parser.idle?                           # true when the machine is in the ground state
parser.reset                           # force back to ground, drop partial state
```

Parsing is synchronous: every callback fires inline, in stream order, before `parse` returns.  
Parser state persists across calls, so a sequence may be split across any number of chunks:

```crystal
parser.parse("\e[")
parser.parse("31")
parser.parse("m")   # csi_dispatch fires here
```

`idle?` is useful for deciding whether a read boundary is a safe place to flush rendered output.

## Handlers

Three layers are available, from lowest to highest level.

### `VT::Handler`

The raw callback interface.  
All methods are abstract; include this only when you intend to implement every event.

### `VT::BaseHandler`

`VT::Handler` with no-op implementations for every callback.  
Include it and override only what you care about.  
This is the usual starting point.

### `VT::BufferedHandler`

Builds on `BaseHandler` and adds two conveniences:

- Bytes in the ground state are fed through a streaming UTF-8 decoder, so you receive `print(char : Char)` for complete codepoints instead of raw bytes.
- String payloads (OSC, DCS, SOS, PM, APC) are accumulated and delivered once, complete, instead of byte by byte.

```crystal
class Screen
  include VT::BufferedHandler

  def print(char : Char)
    STDOUT << char
  end

  def osc_dispatch(payload : String, overflow : Bool)
    return if overflow
    scanner = VT::Scanner.new(payload)
    case scanner.next_i32
    when 0, 2
      title = scanner.next_str
      puts "title: #{title}" if scanner.complete?
    end
  end

  def dcs_dispatch(char : UInt8, params : Array(VT::Parameter), intermediates : Array(UInt8), ignore : Bool, payload : String, overflow : Bool)
  end

  def sos_dispatch(payload : String, overflow : Bool)
  end

  def pm_dispatch(payload : String, overflow : Bool)
  end

  def apc_dispatch(payload : String, overflow : Bool)
  end
end

handler = Screen.new
handler.payload_limit = 64 * 1024
VT::Parser.new(handler).parse("\e]0;my terminal\a")
```

`payload_limit` defaults to `1_048_576` bytes.  
When a payload exceeds it, the excess is discarded, `overflow` is `true` on dispatch, and the truncated prefix is still delivered.  
All five `*_dispatch` methods are abstract and must be implemented, along with `print(char : Char)`.  

The byte-level callbacks are still available if you override them, but doing so replaces the buffering behaviour for that event.

## Callback reference

| Callback                                            | Fired when                                                                        |
|-----------------------------------------------------|-----------------------------------------------------------------------------------|
| `print(char : UInt8)`                               | A printable byte (`0x20`–`0xFF`) is seen in the ground state.                     |
| `execute(char : UInt8)`                             | A C0 control byte is seen.                                                        |
| `clear`                                             | A new escape sequence begins; drop accumulated state.                             |
| `collect(char : UInt8)`                             | An intermediate byte (`0x20`–`0x2F`) or a private marker (`0x3C`–`0x3F`) is seen. |
| `param(char : UInt8)`                               | A parameter byte — digit, `;` or `:` — is seen.                                   |
| `esc_dispatch(char, intermediates, ignore)`         | A plain escape sequence finalizes.                                                |
| `csi_dispatch(char, params, intermediates, ignore)` | A CSI sequence finalizes.                                                         |
| `hook(char, params, intermediates, ignore)`         | A DCS sequence enters its payload.                                                |
| `put(char : UInt8)`                                 | A DCS payload byte arrives.                                                       |
| `unhook`                                            | The DCS payload ends.                                                             |
| `osc_start` / `osc_put` / `osc_end`                 | OSC payload lifecycle.                                                            |
| `sos_start` / `sos_put` / `sos_end`                 | SOS payload lifecycle.                                                            |
| `pm_start` / `pm_put` / `pm_end`                    | PM payload lifecycle.                                                             |
| `apc_start` / `apc_put` / `apc_end`                 | APC payload lifecycle.                                                            |

The `params` and `intermediates` slices passed to `csi_dispatch` and `hook` are views into the parser's internal storage.  
They are valid for the duration of the call only; copy them with `to_a` if you need to keep them.

## Parameters

`VT::Parameter` carries a value and a sub-parameter flag.

```crystal
param.value      # Int32, -1 when the sender omitted it
param.sub        # true when delimited by ':' rather than ';'
param.empty?     # value == -1
param.fetch(1)   # value, or the given default when empty
```

Omitted parameters are preserved rather than collapsed, so `\e[;1;;m` yields four parameters: `-1`, `1`, `-1`, `-1`.  
Sub-parameters keep their position in the flat list, with `sub` marking continuation: `\e[38:2:255:0:100m` yields five parameters where the last four are sub-parameters of the first.

Values that would overflow are clamped to `Int32::MAX` rather than wrapping.

## `VT::Control`

Common C0 codes as an enum, for readable `execute` handling:

```crystal
def execute(char : UInt8)
  case char
  when VT::Control::LF.value  then newline
  when VT::Control::CR.value  then carriage_return
  when VT::Control::BEL.value then bell
  end
end
```

Members: `NUL`, `BEL`, `BS`, `HT`, `LF`, `VT`, `FF`, `CR`, `ESC`.

## `VT::Scanner`

A struct for pulling semicolon-delimited fields out of OSC and DCS payloads.  
It never raises; on malformed input it latches an invalid state and returns zero values, so you validate once at the end instead of at every step.

```crystal
scanner = VT::Scanner.new("4;16;rgb:ff/00/00")

index = scanner.next_i32
color = scanner.next_str

if scanner.complete?
  apply(index, color)
end
```

| Method        | Behaviour                                                |
|---------------|----------------------------------------------------------|
| `next_i32`    | Signed integer, honouring a leading `-`.                 |
| `next_u32`    | Unsigned integer.                                        |
| `next_bool`   | `1` is true, `0` is false.                               |
| `next_action` | A single byte followed by a delimiter or end of payload. |
| `next_str`    | Everything up to the next `;`.                           |
| `valid?`      | False once a malformed token has been read.              |
| `complete?`   | True when the payload was consumed and remained valid.   |

A trailing delimiter with nothing after it invalidates the scanner, so `"1;2;"` is treated as malformed rather than yielding a phantom empty field.

## `VT::UTF8`

The streaming decoder used by `BufferedHandler`, usable standalone.  
It holds no heap state and tolerates being fed one byte at a time.

```crystal
class Decoder
  include VT::UTF8
end

decoder = Decoder.new
decoder.decode_byte(0xE2_u8)  # nil, more bytes expected
decoder.decode_byte(0x82_u8)  # nil
decoder.decode_byte(0xAC_u8)  # '€'
```

Invalid lead bytes produce `U+FFFD` immediately.

## `VT::DSL`

Macros for routing dispatch events without hand-writing comparison chains.

```crystal
class Terminal
  include VT::BaseHandler
  include VT::DSL

  def csi_dispatch(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    return if ignore

    on_csi 'm' do
      set_graphics(params)
    end

    on_csi ['H', 'f'] do
      move_cursor(params[0]?.try(&.fetch(1)) || 1, params[1]?.try(&.fetch(1)) || 1)
    end

    on_csi 'h', intermediates: '?' do
      set_private_mode(params)
    end
  end

  def hook(char : UInt8, params : Slice(VT::Parameter), intermediates : Slice(UInt8), ignore : Bool)
    on_dcs 'q', intermediates: '$' do
      begin_decrqss
    end
  end
end
```

`on_csi` and `on_dcs` accept a single character or an array of characters, plus optional intermediates as a character or array of characters.  
Omitting `intermediates:` matches only sequences that carry none, so `\e[m` and `\e[?m` never collide.  
Both macros expand in place and read the `char` and `intermediates` locals from the enclosing method, so keep the parameter names as shown.

## Parsing behaviour

Some details worth knowing when writing a handler.

- **Eight-bit C1 controls are not sequence introducers.** Bytes `0x80`–`0xFF` in the ground state are printable, which is what a UTF-8 stream requires. Use the seven-bit forms (`ESC [`, `ESC ]`, `ESC P`) for sequences.
- **Limits set a flag, not an error.** More than 8 intermediates or more than 64 parameters sets `ignore` on dispatch. The sequence is still delivered with the data collected up to the limit; ignoring it is your decision.
- **Aborts fire the closing callback.** `CAN` (`0x18`), `SUB` (`0x1A`) and a new `ESC` terminate any in-progress string sequence, so `osc_end`, `unhook` and friends always run. A `BufferedHandler` therefore still dispatches a truncated payload rather than silently dropping it.
- **OSC accepts either terminator.** `BEL` and `ST` (`ESC \`) both end an OSC string. SOS, PM and APC end on `ST` only. When `ST` is used, `esc_dispatch` fires afterwards with `\` as the final character.
- **C0 controls pass through sequences.** A control byte arriving mid-CSI is executed without disturbing the sequence in progress, matching hardware behaviour.
- **`DEL` (`0x7F`)** is ignored inside sequences, printed in the ground state, and passed through inside OSC payloads.

## Development

```sh
shards install
crystal spec
```

The parser is verified against a YAML corpus at `spec/corpus/parser.yml`, where each case is an input string and the exact event sequence it must produce.
Adding a regression test means adding an entry there — no Crystal required.

## License

MIT. See [LICENSE](LICENSE).