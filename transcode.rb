#!/usr/bin/ruby -w

require 'optparse'

OPTIONS = {}
OptionParser.new do |opts|
  opts.banner = <<EOUSAGE
Usage: #{File.basename($0)} [OPTION]... DIRECTORY
Transcode to DV all JVC Everio video files.
MPEG-2 PS is detected so the file extension maybe anything, like .MOD or .mpg.
EOUSAGE

  opts.on("-r", "--recursive", "Scan directories recursively") do |v|
    OPTIONS[:recursive] = v
  end

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

if ARGV[0].nil?
  puts <<EOERROR
#{File.basename($0)}: missing directory operand
Try `#{File.basename($0)} --help' for more information.
EOERROR
  exit
else
  dir = File.expand_path ARGV[0]
end

test = `which ffmpeg`
if test.empty?     
  puts <<EOERROR
#{File.basename($0)}: FFmpeg not found!
FFmpeg must be installed. Go to http://ffmpeg.mplayerhq.hu/ for more information.
EOERROR
  exit
end

def scan(dir, counter)
  entries = Dir.entries(dir)
  2.times { entries.shift }
  entries.each do |entry|
    entry = "#{dir}/#{entry}"
    if File.directory? entry
      if OPTIONS[:recursive]
        scan(entry, counter)
      end
    elsif Video.is_mpeg2_file? entry
    
      video = Video.new(entry)
      if video.to_cropped_dv
        counter.increment
      end
    end
  end
end

class Counter
  attr_writer :value

  def initialize
    @value = 0
  end

  def value
    @value
  end

  def increment
    @value += 1
  end
end

class Video
  attr_reader :path, :output_path
  MOD_HEADER = "\x00\x00\x01\xBA\x44\x00\x04\x00"

  def initialize(path)
    @path = path
    @output_path = build_output_path
  end

  def self.is_mpeg2_file?(path)
    
    header = File.open(path) { |f| f.read(8) }
    puts path
    puts "header"
    puts header
    puts "MOD_HEADER"
    puts MOD_HEADER
    header.eql? MOD_HEADER
  end

  def to_cropped_dv
    puts "Transcoding #{path}..."
    if File.exists? output_path
      puts "File exists, skipped."
      result = false
    else
      `ffmpeg -i "#{path}" -aspect 16:9 -deinterlace -target dv "#{output_path}"`
      result = true
    end
    result
  end

private
  def build_output_path
    dirname = File.dirname(path)
    output_dir = "#{dirname}/dv"
    unless File.exists? output_dir
      Dir.mkdir output_dir
    end
    "#{output_dir}/#{dv_basename}"
  end

  def dv_basename
    basename = File.basename(path).split(".")
    if basename.length > 1
      basename.pop
    end
    basename[0] = File.mtime(path).strftime("%Y-%m-%d-%H-%M-").to_s + basename[0]
    basename << "dv"
    basename.join(".")
  end
end

subdir = " and subdirectories" if OPTIONS[:recursive]
puts "Transcoding to DV all JVC Everio MPEG-2 files in #{dir}#{subdir}..."

counter = Counter.new
scan(dir, counter)

if counter.value > 0
  puts "#{counter.value} files transcoded."
else
  puts "No file transcoded."
end
