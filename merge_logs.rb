#!/usr/bin/ruby
#
# This script takes a list of rails log files as input and merges them into a
# single log file in chronological order.
#
require 'optparse'


class MergeLogs

  def initialize
    @source_file_array = []
    @file_ptr_array = []
    @options = {}
  end

  def parse_options
    @options[:verbose] = false
    @options[:destination] = 'full_log.log'
    opts = OptionParser.new do |opts|
      opts.on('-v', '--verbose', 'Get verbose output.') do |v|
        @options[:verbose] = v
      end
      opts.on('-s SOURCE', '--source SOURCE',
              'Specify a file that contains paths of all' +
              ' log files to be merged.') do |s|
        @options[:source] = s
      end
      opts.on('-d DESTINATION', '--destination DESTINATION',
              'Specify the full path of the destination file.') do |d|
        @options[:destination] = d
      end
      opts.on('-l LOGS', '--logs LOGS',
              'Specify paths of all logs to be merged in a comma separated' +
              ' format.') do |l|
        @options[:logs] = l
      end
    end

    begin
      opts.parse!(ARGV)
    rescue OptionParser::ParseError => e
      puts e
      exit 1
    end

    unless ARGV.empty?
      puts "Unexpected arguments #{ARGV.join(' ')}"
      exit 2
    end

    unless @options[:source].nil?
      if File.exists?(@options[:source])
        source_file = File.open(@options[:source], 'r')
        while source_line = source_file.gets
          @source_file_array << source_line[0..-2]
        end
        source_file.close
      end
    end

    if @options[:logs]
      logs = @options[:logs].split(',')
      @source_file_array.concat(logs)
    end

    if @source_file_array.empty?
      puts 'Please specify a valid source file path using -s or ' +
           'specify all logs as comma separated arguments with -l.'
      exit 3
    end
  end

  # This method returns the index of the earliest date value
  # from the date array.
  # Args:
  # - Array of Strings: array of date-time strings
  #
  # Returns:
  # - Fixnum: index of the "earliest" date-time string from the array
  #
  def get_least_date_index(date_array)
    min_index = nil
    min_value = '9999'
    date_array.length.times do |i|
      if date_array[i] && date_array[i] < min_value
        min_value = date_array[i]
        min_index = i
      end
    end
    if @options[:verbose]
      puts "Comparing dates : #{date_array.inspect}"
      puts "Server #{min_index} chosen"
    end
    return min_index
  end

  # This method parses the source_file_array and open all the files in read
  # mode, opens the destination file in write-truncate mode and writes into
  # the destination file, all the logs merged in a chronological order
  #
  def write_out_log
    date_array = []
    first_line_array = []
    dump_file = File.new(@options[:destination], 'w+')
    @source_file_array.length.times do |i|
      if @options[:verbose]
        puts "Opening file : #{@source_file_array[i]}"
      end
      begin
        @file_ptr_array[i] = File.open("#{@source_file_array[i]}", 'r')
      rescue Exception => e
        puts e
        @file_ptr_array.each do |file|
          file.close
        end
        exit 1
      end
      line_content = @file_ptr_array[i].gets
      while line_content && !(line_content =~ /\AProcessing.*/)
        line_content = @file_ptr_array[i].gets
      end
      if line_content =~ /\AProcessing/
        dat = line_content.scan(/\sat\s.*\)/)
        first_line_array[i] = line_content
        dat = dat[0][4..-2] # dat gets a string of the format " at <date-time>)"
                            # this strips off the " at " in the beginning and
                            # the ")" at the end to give us the date-time string
        date_array[i] = dat
      end
    end

    while j = self.get_least_date_index(date_array)
      dump_file.puts(first_line_array[j])
      line_content = @file_ptr_array[j].gets
      while line_content && !(line_content =~ /\AProcessing/)
        dump_file.puts(line_content)
        line_content = @file_ptr_array[j].gets
      end
      if line_content =~ /\AProcessing/
        dat = line_content.scan(/\sat\s.*\)/)
        first_line_array[j] = line_content
        dat = dat[0][4..-2]
        date_array[j] = dat
      elsif line_content.nil?
        date_array[j] = nil
      end
    end
  end

  def close_files
    @file_ptr_array.each do |file|
      file.close
    end
    if @options[:verbose]
      puts "Closed #{@file_ptr_array.length} files."
    end
  end

  def run
    parse_options
    write_out_log
    close_files
  end

end


if __FILE__ == $0
  MergeLogs.new.run
end
