# src/vt/scanner.cr
# A zero-allocation utility for extracting semicolon-delimited arguments
# from string payloads.
struct VT::Scanner
  SEPARATOR = 0x3B_u8
  MINUS     = 0x2D_u8
  ZERO      = 0x30_u8
  NINE      = 0x39_u8

  # Returns true if the scanner is in a valid state and parsing can continue.
  getter? valid : Bool = true

  @payload : String
  @ptr     : Pointer(UInt8)
  @size    : Int32
  @pos     : Int32 = 0

  # Initializes a scanner mapped to the provided string payload.
  def initialize(@payload : String)
    @ptr  = @payload.to_unsafe
    @size = @payload.bytesize
  end

  # Returns true if the entire payload has been consumed.
  def complete? : Bool
    @valid && @pos >= @size
  end

  # Extracts the next single-byte character and advances past the delimiter.
  def next_action : UInt8
    unless @valid && @pos < @size
      @valid = false
      return 0_u8
    end

    byte = @ptr[@pos]
    @pos += 1

    if @pos < @size && @ptr[@pos] != SEPARATOR
      @valid = false
      return 0_u8
    end

    separate
    byte
  end

  # Extracts the next numeric token as an unsigned 32-bit integer.
  def next_u32 : UInt32
    digits(4294967295_i64).to_u32
  end

  # Extracts the next numeric token as a signed 32-bit integer.
  def next_i32 : Int32
    return 0 unless @valid

    if @pos < @size && @ptr[@pos] == MINUS
      @pos += 1
      return (-digits(2147483648_i64)).to_i32
    end

    digits(2147483647_i64).to_i32
  end

  # Extracts the next numeric token and interprets it as a boolean.
  # Represents `1` as true, and any other value as false.
  def next_bool : Bool
    digits(1_i64) == 1
  end

  # Extracts the remainder of the token up to the next semicolon delimiter
  # and returns it as a string slice without allocating new heap memory.
  def next_str : String
    unless @valid && @pos < @size
      @valid = false
      return ""
    end

    start_pos = @pos
    while @pos < @size && @ptr[@pos] != SEPARATOR
      @pos += 1
    end

    value = @payload.byte_slice(start_pos, @pos - start_pos)
    separate
    value
  end

  private def digits(limit : Int64) : Int64
    return 0_i64 unless @valid

    value = 0_i64
    count = 0

    while @pos < @size && (byte = @ptr[@pos]) != SEPARATOR
      if byte < ZERO || byte > NINE
        @valid = false
        return 0_i64
      end

      value = value * 10 + (byte - ZERO)

      if value > limit
        @valid = false
        return 0_i64
      end

      count += 1
      @pos += 1
    end

    if count == 0
      @valid = false
      return 0_i64
    end

    separate
    value
  end

  private def separate : Nil
    return if @pos >= @size
    @pos += 1
    @valid = false if @pos >= @size
  end
end
