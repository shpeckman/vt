# src/vt/utf8.cr
# A zero-allocation streaming UTF-8 decoder mixin.
module VT::UTF8
  @utf8_buf      = StaticArray(UInt8, 4).new(0_u8)
  @utf8_len      = 0_u8
  @utf8_expected = 0_u8

  # Consumes a single byte and returns a decoded `Char` if a valid UTF-8 sequence
  # completes, `nil` if expecting more bytes, or the Unicode replacement character
  # (`U+FFFD`) if an invalid sequence is encountered.
  def decode_byte(byte : UInt8) : Char?
    if @utf8_expected == 0
      if byte <= 0x7F
        return byte.unsafe_chr
      elsif byte >= 0xC2 && byte <= 0xDF
        @utf8_expected = 2_u8
      elsif byte >= 0xE0 && byte <= 0xEF
        @utf8_expected = 3_u8
      elsif byte >= 0xF0 && byte <= 0xF4
        @utf8_expected = 4_u8
      else
        return '\uFFFD'
      end
      @utf8_buf[0] = byte
      @utf8_len = 1_u8
      return nil
    end

    @utf8_buf[@utf8_len] = byte
    @utf8_len += 1_u8

    if @utf8_len == @utf8_expected
      cp = 0
      case @utf8_expected
      when 2_u8
        cp = ((@utf8_buf[0] & 0x1F).to_i << 6) | (@utf8_buf[1] & 0x3F).to_i
      when 3_u8
        cp = ((@utf8_buf[0] & 0x0F).to_i << 12) | ((@utf8_buf[1] & 0x3F).to_i << 6) | (@utf8_buf[2] & 0x3F).to_i
      when 4_u8
        cp = ((@utf8_buf[0] & 0x07).to_i << 18) | ((@utf8_buf[1] & 0x3F).to_i << 12) | ((@utf8_buf[2] & 0x3F).to_i << 6) | (@utf8_buf[3] & 0x3F).to_i
      end

      @utf8_expected = 0_u8
      @utf8_len      = 0_u8
      return cp.unsafe_chr
    end

    nil
  end
end
