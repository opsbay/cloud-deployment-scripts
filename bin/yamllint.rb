#!/usr/bin/env ruby
#
# yamllint.rb
# 
# Lints a YAML file by loading it in Ruby
#
# Syntax:
#    yamllint.rb [-v|--verbose] file1 ...
# Thanks Stack Overflow 
#    https://stackoverflow.com/questions/3971822/yaml-syntax-validator/20420243#20420243
#    https://stackoverflow.com/a/5561070/424301
require 'yaml'
require 'optparse'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: yamllint.rb [-v|--verbose] file.yml [file2.yml] ..."

  opts.on('-v', '--verbose', 'Be verbose, dumping parsed YAML when successful') do ||
    options[:v] = true
  end
end

optparse.parse!

# Check required conditions
if ARGV.empty?
  puts optparse
  exit(-1)
end

ARGV.each { |src|
    yaml = YAML.load_file(src)
    if options[:v] 
        puts YAML.dump(yaml)
    end
}
