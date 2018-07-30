import sys
import os
import datetime
import argparse
from subprocess import call
import re
from os import access, R_OK
from os.path import isfile


def print_start():
    '''
    Prints start program
    '''
    msg = """
# ---------------------------------------- #
#       build.py: Building NetEngine       #
# ---------------------------------------- #
    - Start: %s

""" % datetime.datetime.now().strftime("%a, %d %B %Y %H:%M:%S")
    sys.stderr.write(msg)
    

def get_options():
    '''
    Reads the options
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
    '''
    msg_header = "\n\n# NETENGINE ERROR\n"
    if fatal is True:
    	msg_header += "# [ FATAL ]\n"
    	sys.exit(msg_header + "# " + msg +  "\n")
    else:
    	msg_header += "# [ WARNING ]\n"
    	sys.stderr.write(msg_header + "# " + msg +  "\n")


def read_config(cfile):
    '''
    Reads configuration file.
    Returns option dictionary
    '''
    valid_options = set([
    	"project_name", "output", "neo4j_memory","neo4j_address",
    	"biogrid_file","string_file","ppaxe_file",
    	"drivers_file","alias_file","web_address",
    	"content_templates","logo_img", "databases"
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
    	opt, value = line.split("=")
    	if opt not in valid_options:
    		msg = "Not valid option: %s! Ignoring it..." % opt
    		netengine_error(msg, fatal=False)
    		continue
    	if opt in opts:
    		msg = "Repeated option: %s! Ignoring it..." % opt
    		netengine_error(msg, fatal=False)
    		continue
    	opts[opt] = value
    print(opts)
    return opts


def print_opts(opts):
    '''
    Prints options to stderr
    '''
    valid_options = [
	    "project_name","output", "neo4j_memory","neo4j_address",
	    "biogrid_file","string_file","ppaxe_file",
	    "drivers_file","alias_file","web_address",
	    "content_templates","logo_img", "databases"
    ]
    sys.stderr.write("    OPTIONS:\n")
    for opt in valid_options:
        if opt in opts:
    	   sys.stderr.write("    - %s : %s\n" % (opt, opts[opt]) )


def check_dependencies():
    '''
    Checks dependencies
    '''
    pass


def check_files(filenames):
    '''
    Checks if a particular file exists and build.py has
    reading permissions
    '''
    for file in filenames:
        if not isfile(file) or not access(file, R_OK):
            msg = "Can't read file: %s" % file
            netengine_error(msg, fatal=True)

def check_opts(opts):
    '''
    Checks options and sets default parameters for missing opts
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

    filenames = [ opts[filename] for filename in opts.keys() if filename.find("_file") > 0 ]
    #check_files(filenames)


def create_dirs(opts):
    '''
    Creates all output directories
    '''
    directories = ['plots', 'graphs', 'tables', 'django-project', 'logs', 'databases']
    for direct in directories:
        try:
            os.mkdir(os.path.join(opts['output'], direct))
        except OSError as err:
            netengine_error(str(err), fatal=False)



def build_graph(opts):
    '''
    Creates the graph files
    '''
    cmd = list()
    cmd.append(opts['bin'] + '/' + 'filter_interactions_to_graph.pl')
    cmd.append('ids:%s' % opts['drivers_file'])
    cmd.append(opts['alias_file'])
    cmd.append(opts['output'] + '/graphs')
    graph_files = [ 
        graphname for graphname in ('biogrid_file', 'string_file', 'ppaxe_file') if graphname in opts 
        ]
    graph_names = [ file.replace("_file", "") for file in graph_files ]
    #print ",".join(cmd)
    for name, file in zip(graph_names, graph_files):
        subcmd = '%s:%s' % (name, opts[file]) 
        cmd.append(subcmd)
    #call([ filter_interactions, '-h' ])


def download_interactions(opts):
    '''
    Takes options and downloads interaction files from 'databases'.
    os.path.join(opts['output'], 'databases)'
    '''
    # Check databases 
    # Download database 1
        # call('wget webpage')
    # Download database 2
    # 



def main():
    cmdopts = get_options()
    print_start()
    check_dependencies()
    opts = read_config(cmdopts.config)
    opts['base_dir'] = os.path.dirname(os.path.abspath(__file__))
    opts['bin'] = os.path.join(opts['base_dir'], 'bin')
    opts['data'] = os.path.join(opts['base_dir'], 'data')
    check_opts(opts)
    download_interactions(opts)
    print_opts(opts)
    create_dirs(opts)
    build_graph(opts)


if __name__ == "__main__":
    main()

