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
from py2neo import Graph
import graph_tool.all as gt
import numpy as numpy


VALID_OPTIONS = set([
        "project_name", "output", "neo4j_memory","neo4j_address",
        "biogrid_file","string_file","ppaxe_file",
        "drivers_file","alias_file","web_address",
        "content_template","logo_img", "download_databases", "drivers_ext",
        "nvariants_file", "gene_ontology_file", "download_gene_ontology"
    ])

INCOMPATIBLE_OPTIONS = {
    "biogrid_file": "download_databases",
    "string_file": "download_databases",
    "ppaxe_file": "download_databases",
    "gene_ontology_file": "download_gene_ontology"
}


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
#       build.py: Building netcutter       #
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
    parser = argparse.ArgumentParser(description='Command-line tool to build a netcutter network.')
    parser.add_argument(
        '-c','--config',
        help='netcutter configuration file.', required=True
    )
    try:
        options = parser.parse_args()
    except argparse.ArgumentError:
        parser.print_help()
        sys.exit(0)
    return options


def netcutter_error(msg, fatal=True):
    '''
    Deals with errors 

    Args:
        msg: String to print to stderr.
        fatal: Boolean indicating if program should be terminated or not.

    Returns:
        None

    '''
    msg_header = "\n\n     # netcutter ERROR\n"
    if fatal is True:
    	msg_header += "     # [ FATAL ]\n"
    	sys.exit(msg_header + "     # " + msg +  "\n")
    else:
    	msg_header += "     # [ WARNING ]\n"
    	sys.stderr.write(msg_header + "     # " + msg +  "\n")


def netcutter_msg(msg):
    '''
    Prints messages to stderr

    Args:
        msg: String to print to stderr.

    Returns:
        None
    '''
    msg_header = "     # [ MESSAGE ]\n"
    sys.stderr.write("\n" + msg_header + "     # " + msg +  "\n")


def read_config(cfile):
    '''
    Reads configuration file.

    Args:
        cfile: Configuration file.

    Returns:
        Config options dictionary.
    
    '''

    opts = dict()
    try:
    	fh = open(cfile, "r")
    except Exception:
    	msg = "Config file not found. Can't read: %s" % cfile
    	netcutter_error(msg, fatal=True)
    for line in fh:
    	line = line.strip()
    	if line.startswith("#") or not line:
    		continue
        try:
    	   opt, value = line.split("=")
        except ValueError:
            msg = "Invalid config parameter: %s" % line
            netcutter_error(msg, fatal=True)
    	if opt not in VALID_OPTIONS:
    		msg = "Invalid config parameter: %s" % opt
    		netcutter_error(msg, fatal=True)
    		continue
    	if opt in opts:
    		msg = "Repeated option: %s! Ignoring it..." % opt
    		netcutter_error(msg, fatal=False)
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
    sys.stderr.write("    OPTIONS:\n")
    for opt in sorted(list(VALID_OPTIONS)):
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
            netcutter_error(msg, fatal=True)


def check_incompatible_opts(opts):
    '''
    Checks if the user provided incompatible options

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    to_remove = list()
    for dom_opt, nd_op in INCOMPATIBLE_OPTIONS.iteritems():
        if dom_opt in opts and nd_op in opts:
            netcutter_error("Incompatible options '%s' and '%s' provided. Going to use '%s'." % (dom_opt, nd_op, dom_opt), fatal=False)
            to_remove.append(nd_op)

    for opt in to_remove:
        if opt in opts: del opts[opt]


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
    	netcutter_error(msg, fatal=True)

    if 'drivers_file' not in opts:
    	msg = "Drivers file required!"
    	netcutter_error(msg, fatal=True)

    if 'drivers_ext' not in opts:
        opts['drivers_ext'] = False
    else:
        if opts['drivers_ext'] != "True" and opts['drivers_ext'] != "False":
            netcutter_error("Configuration parameter drivers_ext has to be True or False", fatal=True)
        else:
            opts['drivers_ext'] = True if opts['drivers_ext'].lower() == 'true' else False
    filenames = [ opts[filename] for filename in opts.keys() if filename.find("_file") > 0 ]
    check_incompatible_opts(opts)
    check_files(filenames)


def connect_to_neo4j(opts):
    '''
    Connects to neo4j graph database

    Args:
        opts: config options dictionary.

    Returns:
        Neo4j Graph object
    '''
    try:
        graph = Graph("http://127.0.0.1:7474/db/data/", password="1234")
        return graph
    except Exception as err:
        netcutter_error("Can't connect to neo4j - %s" % err, fatal=True)



def read_skeleton(dfile):
    '''
    Reads driver genes from file.

    Args:
        dfile: graph file

    Returns:
        i_nodes: Names/symbols of nodes of interest
    '''
    fh = open(dfile, "r")
    i_nodes = set()
    next(fh)
    for line in fh:
        line = line.strip()
        columns = line.split(";")
        if int(columns[2]) != 0:
            # Skip interactions not in skeleton
            continue
        i_nodes.add(columns[0])
        i_nodes.add(columns[1])
    return i_nodes


def read_graph(filename):
    '''
    Reads graph converting it into graph_tool Graph

    Args:
        filename: csv graph file.

    Returns:
        graph: graph_tool Graph object.
        vprop: property map containing symbols/names for genes in graph.
    '''
    fh        = open(filename, "r")
    graph     = gt.Graph(directed=True)
    vprop     = graph.new_vertex_property("string")
    node_dict = dict()
    node_idx  = 0
    next(fh) # skip header
    for line in fh:
        line = line.strip()

        elements = line.split(";")
        s, t = str(), str()

        if len(elements) == 1:
            s = elements[0]
        else:
            s, t = elements[0], elements[1]

        # Add vertices
        if s and s not in node_dict:
            source         = graph.add_vertex()
            node_dict[s]   = source
            vprop[source]  = s
        if t and t not in node_dict:
            target         = graph.add_vertex()
            node_dict[t]   = target
            vprop[target]  = t

        # Add edge
        if s and t:
            graph.add_edge(node_dict[s], node_dict[t])
    return graph, vprop


def print_shortest_paths(graph, vprop, iprop, out):
    '''
    Prints shortest paths for a given 
    Args:
        graph: graph_tool graph.
        vprop: property map with names/symbols.
        iprop: names of skeleton genes.
        out:   output filename.

    Returns:
        graph: graph_tool Graph object.
        vprop: property map containing symbols/names for genes in graph.
    '''
    ofh = open(out, "w")
    for v1 in graph.vertices():
        for v2 in graph.vertices():
            if vprop[v2] not in iprop:
                continue
            vlist, elist = gt.shortest_path(graph, v1, v2)
            if vlist:
                ofh.write("%s to %s," % (vprop[v1], vprop[v2]))
                ofh.write(",".join([ vprop[vp] for vp in vlist ]))
                ofh.write("\n")
    ofh.close()


def read_drivers(dfile):
    '''
    Reads driver genes

    Args:
        dfile: drivers genes file.

    Returns:
        drivers: set with drivers gene names/symbols.
    '''
    fh = open(dfile, "r")
    drivers = set()
    next(fh)
    for line in fh:
        line = line.strip()
        columns = line.split(",")
        drivers.add(columns[0])
    return drivers


def get_paths(drivers, pfile):
    '''
    reads pathways computed by graph_tool

    Args:
        drivers: set with drivers gene names/symbols.
        pfile: file with pathways

    Returns:
        paths: dictionary of dictionary of arrays.
               gene => ['drivers' | 'skeleton' ] => [gene1, gene2, ...]
    '''
    fh = open(pfile)
    paths = dict()
    for line in fh:
        line = line.strip()
        columns = line.split(",")
        columns = columns[1:len(columns)]
        gene = columns[0]
        target = columns[-1]
        plen = len(columns) - 1
        pkey = "skeleton"
        if gene in drivers:
            continue
        if target in drivers:
            pkey = "drivers"
        if gene not in paths:
            # Initialize new gene
            paths[gene] = dict()
            paths[gene][pkey] = list()
            paths[gene][pkey].append(columns)
        else:
            if pkey not in paths[gene]:
                # Initialize path for gene
                paths[gene][pkey] = list()
                paths[gene][pkey].append(columns)
            else:
                # Check if current path is shorter than previous
                if len(columns) < len(paths[gene][pkey][0]):
                    # Remove all previous longer paths
                    paths[gene][pkey] = list()
                    paths[gene][pkey].append(columns)
                elif len(columns) == len(paths[gene][pkey][0]):
                    # Same length, add path to list
                    paths[gene][pkey].append(columns)
                else:
                    # Longer path
                    continue
    return paths


def print_unique_paths(opts, paths):
    '''
    Prints to out file unique shortest paths for each gene to drivers or skeleton.

    Args:
        paths: dictionary of dictionary of arrays.
               gene => ['drivers' | 'skeleton' ] => [gene1, gene2, ...]
        out: filename to output pathways

    Returns:
        None
    '''
    has_path_fh = open(os.path.join(opts['output'], 'neo4j', 'import', 'has_path.csv'), "w")
    is_in_path_fh = open(os.path.join(opts['output'], 'neo4j', 'import', 'is_in_path.csv'), "w")
    for gene, path_to in paths.iteritems():
        if 'drivers' in path_to:
            for path in path_to['drivers']:
                length = len(path) - 1
                has_path_fh.write( "%s,%s,%s,%s\n" % (gene, -1, str(length), path[-1]) )
                i = 1
                for node in path[1:]:
                    is_in_path_fh.write( "%s,%s,%s,%s,%s\n" % ( gene, path[-1], node, str(i), str(-1)) )
                    i += 1
        if 'skeleton' in path_to:
            for path in path_to['skeleton']:
                length = len(path) - 1
                ofh.write( "%s,%s,%s\n" % (gene, 0, str(length), ",".join(path)) )
                i = 1
                for node in path[1:]:
                    is_in_path_fh.write( "%s,%s,%s,%s,%s\n" % ( gene, path[-1], node, str(i), str(0)) )
                    i += 1
    has_path_fh.close()
    is_in_path_fh.close()
    return