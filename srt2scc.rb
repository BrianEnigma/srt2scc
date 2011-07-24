#!/usr/bin/ruby

class Caption
  attr_accessor :time_start, :time_end, :text
  def valid?
    return nil != @time_start && nil != @time_end && nil != text &&
      @time_start.length > 0 && @time_end.length > 0 && @text.length > 0
  end
end

class CaptionParser
  def initialize
    @number_regex = Regexp.new(/^[0-9]+$/)
    @time_regex = Regexp.new(/([0-9:,.]+) --> ([0-9:,.]+)/)
  end

  def parse(input)
    result = Array.new
    caption = Caption.new
    # Scan through input
    while (!input.eof?)
      line = input.readline.strip
      number_match = @number_regex.match(line)
      time_match = @time_regex.match(line)
      # At new caption?  Save the old one.
      if nil != number_match && caption.valid?
        result << caption
        caption = Caption.new
      end
      if nil != time_match && time_match.length >= 3
        caption.time_start = time_match[1]
        caption.time_end = time_match[2]
      end
      if nil == number_match && nil == time_match && line.length > 0
        caption.text = "#{caption.text}#{line}\n"
      end
    end
    # Save the final one
    result << caption if caption.valid?
    return result
  end
end

class SccWriter
  def write_header
    print "Scenarist_SCC V1.0\n\n"
  end
  private :write_header

  # Use high bit as odd parity bit
  def odd_parity(b)
    result = b
    bit_count = 0
    while (b > 0)
      bit_count += 1 if (b & 0x01) == 0x01
      b = b >> 1
    end
    result |= 0x80 if (bit_count % 2) == 0
    return result
  end
  private :odd_parity

  def write_string(s)
    # make even length
    length_counter = 0
    s.each_byte { |b|
      length_counter += 1 if "\n"[0] != b
    }
    s << " " if (length_counter % 2) == 1
    counter = 0
    s.each_byte { |b|
      if "\n"[0] == b
        print "94ad " # CR code
        next
      end
      print odd_parity(b).to_s(16)
      counter += 1
      print " " if (counter % 2) == 0
    }
  end
  private :write_string

  def write_entry(caption)
    print "#{caption.time_start.gsub(/,[0-9][0-9][0-9]/, ':00')}\t"
    #      ENM  ENM  RCL  RCL  RU3  RU3
    print "94ae 94ae 9420 9420 9426 9426 "
    text = ''
    caption.text.split("\n").each { |line|
      line.strip!
      line.upcase!
      line << " " while line.length < 32
      line = line[0..31] if line.length > 32
      text << line
      text << "\n"
    }
    text.strip! # remove final trailing \n
    #print "#{text}"
    write_string(text)
    print "\n\n"
    #                                                           EDM  EDM
    print "#{caption.time_end.gsub(/,[0-9][0-9][0-9]/, ':00')}\t942c 942c\n\n"
  end

  def write_entries(caption_array)
    write_header
    caption_array.each { |caption| write_entry(caption) }
  end
end

if ARGV.length > 0
  input = File.new(ARGV[0], "r");
else
  input = STDIN
end

parser = CaptionParser.new
captions = parser.parse(input)
writer = SccWriter.new
writer.write_entries(captions)

