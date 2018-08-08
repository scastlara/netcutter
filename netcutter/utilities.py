# ---------------------------------------------------------------- #
# UTILITIES FOR NETCUTTER
# ---------------------------------------------------------------- #

import sys
import os
import datetime
import argparse
from subprocess import call
import re
from os import access, R_OK
from os.path import isfile
from functools import wraps


def get_time():
    '''
    Args:
        None

    Returns:
        Returns time in a useful format
    '''    
    return datetime.datetime.now().strftime("%a, %d %B %Y %H:%M:%S")

def get_time():
    '''
    Args:
        None

    Returns:
        Returns time in a useful format
    '''    
    return datetime.datetime.now().strftime("%a, %d %B %Y %H:%M:%S")

def print_start():
    '''
    Prints starting program report to stderr.

    Args:
        None

    Returns:
        None
    '''
    msg = """
# ---------------------------------------- #
#       build.py: Building NetEngine       #
# ---------------------------------------- #
    - Start: %s

""" % get_time()
    sys.stderr.write(msg)


def get_options():
    '''
    Reads command line options

    Args:
        None

    Returns:
        options dictionary

    '''
    parser = argparse.ArgumentParser(description='Command-line tool to build a NetEngine network.')
    parser.add_argument(
        '-c','--config',
        help='NetEngine configuration file.', required=True
    )
    try:
        options = parser.parse_args()
    except argparse.ArgumentError:
        parser.print_help()
        sys.exit(0)
    return options


def netengine_error(msg, fatal=True):
    '''
    Deals with errors 

    Args:
        msg: String to print to stderr.
        fatal: Boolean indicating if program should be terminated or not.

    Returns:
        None

    '''
    msg_header = "\n\n\t# NETENGINE ERROR\n"
    if fatal is True:
    	msg_header += "\t# [ FATAL ]\n"
    	sys.exit(msg_header + "\t# " + msg +  "\n")
    else:
    	msg_header += "\t# [ WARNING ]\n"
    	sys.stderr.write(msg_header + "\t# " + msg +  "\n")


def read_config(cfile):
    '''
    Reads configuration file.

    Args:
        cfile: Configuration file.

    Returns:
        Config options dictionary.
    
    '''

    valid_options = set([
    	"project_name", "output", "neo4j_memory","neo4j_address",
    	"biogrid_file","string_file","ppaxe_file",
    	"drivers_file","alias_file","web_address",
    	"content_templates","logo_img", "databases", "drivers_ext",
        "nvariants_file"
    ])
    opts = dict()
    try:
    	fh = open(cfile, "r")
    except Exception:
    	msg = "Config file not found. Can't read: %s" % cfile
    	netengine_error(msg, fatal=True)
    for line in fh:
    	line = line.strip()
    	if line.startswith("#") or not line:
    		continue
        try:
    	   opt, value = line.split("=")
        except ValueError:
            msg = "Invalid config parameter: %s" % line
            netengine_error(msg, fatal=True)
    	if opt not in valid_options:
    		msg = "Invalid config parameter: %s" % opt
    		netengine_error(msg, fatal=True)
    		continue
    	if opt in opts:
    		msg = "Repeated option: %s! Ignoring it..." % opt
    		netengine_error(msg, fatal=False)
    		continue
    	opts[opt] = value
    return opts


def print_opts(opts):
    '''
    Prints options to stderr.

    Args:
        opts: config options dictionary.

    Returns:
        None
    
    '''
    valid_options = [
	    "project_name","output", "neo4j_memory","neo4j_address",
	    "biogrid_file","string_file","ppaxe_file",
	    "drivers_file","alias_file","web_address",
	    "content_templates","logo_img", "databases", "drivers_ext",
        "nvariants_file"
    ]
    sys.stderr.write("    OPTIONS:\n")
    for opt in valid_options:
        if opt in opts:
    	   sys.stderr.write("    - %s : %s\n" % (opt, opts[opt]) )


def check_dependencies():
    '''
    Checks if dependencies are installed/available.

    Args:
        None

    Returns:
        None

    '''
    pass


def check_files(filenames):
    '''
    Checks if all necessary files listed in config file
    are readable.

    Args:
        filenames: list of filenames.

    Returns:
        None

    '''
    for file in filenames:
        if not isfile(file) or not access(file, R_OK):
            msg = "Can't read file: %s" % file
            netengine_error(msg, fatal=True)


def check_opts(opts):
    '''
    Checks if config options are correct. Changes necessary option 
    values accordingly.

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''
    defaults = {
	    'neo4j_memory': '2g', 'neo4j_address': 'localhost:7474',
	    'web_address': 'localhost:8000', 'output': './'
    }

    for opt, default in defaults.iteritems():
    	if opt not in opts:
    		opts[opt] = default

    if ('biogrid_file' not in opts 
    	and  'string_file' not in opts
    	and 'ppaxe_file' not in opts):
    	msg = "Biogrid, String or PPaxe file required!"
    	netengine_error(msg, fatal=True)

    if 'drivers_file' not in opts:
    	msg = "Drivers file required!"
    	netengine_error(msg, fatal=True)

    if 'drivers_ext' not in opts:
        opts['drivers_ext'] = False
    else:
        if opts['drivers_ext'] != "True" and opts['drivers_ext'] != "False":
            netengine_error("Configuration parameter drivers_ext has to be True or False", fatal=True)
        else:
            opts['drivers_ext'] = True if opts['drivers_ext'].lower() == 'true' else False
    filenames = [ opts[filename] for filename in opts.keys() if filename.find("_file") > 0 ]
    check_files(filenames)

