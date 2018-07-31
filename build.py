import sys
import os
import datetime
import argparse
from subprocess import call
import re
from os import access, R_OK
from os.path import isfile


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

    Args:
        cfile: Configuration file.

    Returns:
        Config options dictionary.
    
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
	    "content_templates","logo_img", "databases"
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
    Checks if config options are correct.

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

    filenames = [ opts[filename] for filename in opts.keys() if filename.find("_file") > 0 ]
    check_files(filenames)


def create_dirs(opts):
    '''
    Creates all necessary directories into the output folder.

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''
    directories = ['plots', 'graphs', 'tables', 'django-project', 'logs', 'databases']
    for direct in directories:
        try:
            os.mkdir(os.path.join(opts['output'], direct))
        except OSError as err:
            netengine_error(str(err), fatal=False)

def print_job(name, done=False):
    if done is False:
        sys.stderr.write("\n# ---------------------------------------- #\n")
        sys.stderr.write("# JOB NAME: %s\n" % name.upper())
        sys.stderr.write("# ---------------------------------------- #\n")
        sys.stderr.write("    - Starting job: %s \n" % get_time())
    else:
        sys.stderr.write("    - Finished: %s \n\n" % get_time())


def build_graph(opts):
    '''
    Creates graph files using filter_interactions_to_graph.pl

    Args:
        opts: config options dictionary

    Returns:
        None

    '''
    job_name = "Build graph"
    print_job(job_name)
    cmd = list()
    cmd.append(opts['bin'] + '/' + 'filter_interactions_to_graph.pl')
    cmd.append('ids:%s' % opts['drivers_file'])
    cmd.append(opts['alias_file'])
    cmd.append(os.path.join(opts['output'], 'graphs/graphs'))
    graph_files = [ 
        graphname for graphname in ('biogrid_file', 'string_file', 'ppaxe_file') if graphname in opts 
        ]
    graph_names = [ file.replace("_file", "") for file in graph_files ]
    for name, file in zip(graph_names, graph_files):
        subcmd = '%s:%s' % (name, opts[file]) 
        cmd.append(subcmd)
    call(cmd)
    print_job(job_name, done=True)

def graph_2_csv(opts):
    '''
    Converts graph files to csv ready for uploading to neo4j.

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''

def download_interactions(opts):
    '''
    Downloads interactions from the specified databases (biogrid or string)

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''



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
    # Prepare graphs to be uploaded to neo4j

    # Create plots and tables

    # Start neo4j docker image

    # Upload graphs to neo4j

    # Create templates for django project

    # Build django webpage

    # Test django page??

    # Set it up with uwgsi/docker



if __name__ == "__main__":
    main()

