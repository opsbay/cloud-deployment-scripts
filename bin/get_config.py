#!/usr/bin/env python
import sys
from ConfigParser import SafeConfigParser

parser = SafeConfigParser()

if len(sys.argv) < 2:
    print('ERROR: You must specify command line arguments')
    print('syntax:')
    print('    get_config.py input_file section key')
    sys.exit(1)

input_file = sys.argv[1]
section = sys.argv[2]
key = sys.argv[3]

parser.read(input_file)

print(parser.get(section, key))
