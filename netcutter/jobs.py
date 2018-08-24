# ---------------------------------------------------------------- #
# JOBS FOR NETCUTTER
# ---------------------------------------------------------------- #
from functools import wraps
import sys
import os
from subprocess import call
import re
from functools import wraps
from netcutter import utilities
import pkg_resources
import subprocess
import time
import wget
import pprint

def job(job_name):
    '''
    Decorator for jobs.
    Add @job('JOB-NAME') to a function to make it a job
    '''
    def job_decorator(func):
        @wraps(func)
        def wrapped_function(*args, **kwargs):
            try:
                print_job(job_name, done=False)
                func(*args, **kwargs)
                print_job(job_name, done=True)
            except Exception as err:
                msg = "Job Error - %s: %s" % (job_name, err)
                utilities.netcutter_error(msg, fatal=True)
        return wrapped_function
    return job_decorator


@job("Create directories")
def create_dirs(opts):
    '''
    Creates all necessary directories into the output folder.

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''
    directories = ['plots', 'graphs', 'tables', 
                   'django-project', 'logs', 'databases', 'GO',
                   'neo4j', os.path.join('neo4j', 'import'), os.path.join('neo4j', 'data'), 
                   os.path.join('neo4j', 'logs'), os.path.join('neo4j', 'conf')]
    for direct in directories:
        try:
            os.mkdir(os.path.join(opts['output'], direct), 0777)
        except OSError as err:
            utilities.netcutter_error(str(err), fatal=False)

def print_job(name, done=False):
    if done is False:
        sys.stderr.write("\n# ---------------------------------------- #\n")
        sys.stderr.write("# JOB: %s\n" % name.upper())
        sys.stderr.write("# ---------------------------------------- #\n")
        sys.stderr.write("\n     - Starting job: %s \n" % utilities.get_time())
    else:
        sys.stderr.write("\n     - Finished: %s \n\n" % utilities.get_time())


@job("Build graph")
def build_graph(opts):
    '''
    Creates graph files using filter_interactions_to_graph.pl

    Args:
        opts: config options dictionary

    Returns:
        None

    '''
    cmd = list()
    cmd.append('filter_interactions_to_graph.pl')
    drivers_type = 'ids'
    if opts['drivers_ext'] is True:
        drivers_type = 'ext'
    cmd.append('%s:%s' % (drivers_type, opts['drivers_file']) )
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


@job("Edges to csv")
def edges_2_csv(opts):
    '''
    Converts graph files to csv with edges ready for uploading to neo4j.

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''
    cmd = list()
    cmd.append('edge2neo4jcsv.pl')
    cmd.append('-wholegraph')
    cmd.append(os.path.join(opts['output'], 'graphs', 'graphs_wholegraph.dot'))
    cmd.append('-alias')
    cmd.append(os.path.join(opts['output'], 'graphs', 'graphs_IDalias.tbl'))
    cmd.append('-json')
    cmd.append(os.path.join(opts['output'], 'graphs', 'graphs_wholegraph.json'))
    cmd.append('-maxlvl')
    cmd.append('4')
    cmd.append('-prefix')
    cmd.append(os.path.join(opts['output'], 'graphs', 'graphs_graph_lvl+'))
    cmd.append('-output')
    cmd.append(os.path.join(opts['output'], 'neo4j', 'import', 'edges.csv'))

    call(cmd)


@job("Nodes to csv")
def nodes_2_csv(opts):
    '''
    Converts graph files to csv with nodes ready for uploading to neo4j.

    Args:
        opts: config options dictionary.

    Returns:
        None

    '''
    cmd = list()
    cmd.append('node2neo4jcsv.pl')
    cmd.append('-wholegraph')
    cmd.append(os.path.join(opts['output'], 'graphs', 'graphs_wholegraph.dot'))
    cmd.append('-alias')
    cmd.append(os.path.join(opts['output'], 'graphs' ,'graphs_IDalias.tbl'))
    if 'nvariants_file' in opts:
        cmd.append("-nvariants")
        cmd.append(opts['nvariants_file'])

    cmd.append('-drivers')
    cmd.append(opts['drivers_file'])
    cmd.append('-maxlvl')
    cmd.append('4')
    cmd.append('-prefix')
    cmd.append(os.path.join(opts['output'], 'graphs', 'graphs_graph_lvl+'))
    cmd.append('-output')
    cmd.append(os.path.join(opts['output'], 'neo4j', 'import', 'nodes.csv'))
    call(cmd)



@job("Pull neo4j docker")
def pull_neo4j_docker(opts):
    '''
    Pulls neo4j docker image

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    cmd = list()


@job("Pull neo4j docker")
def pull_neo4j_docker(opts):
    '''
    Pulls neo4j docker image

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    cmd = list()


@job("Download GeneOntologies")
def download_go(opts):
    '''
    Download Gene Ontologies from Biomart

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    go_url = 'http://www.ensembl.org/biomart/martservice?query=<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE Query><Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.6" >                <Dataset name = "hsapiens_gene_ensembl" interface = "default" >        <Attribute name = "hgnc_symbol" />        <Attribute name = "go_id" />        <Attribute name = "name_1006" />        <Attribute name = "namespace_1003" />    </Dataset></Query>'    
    try:        
        go_file = os.path.join(opts['output'], 'GO', 'gene_ontologies.txt')
        filename = wget.download(go_url, out=go_file, bar=None)
        opts['gene_ontology_file'] = go_file
    except Exception as err:
        utilities.netcutter_error("Can't download GO file - %s" % err, fatal=True)


@job("GeneOntologies to csv")
def go_to_csv(opts):
    '''
    Prepares to gene ontology files for uploading them to neo4j

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    fh = open(opts['gene_ontology_file'], "r")
    gos = dict()
    gene_2_go = dict()
    for line in fh:
        line = line.strip()
        cols = line.split("\t")
        if len(cols) != 4:
            continue
        if cols[1] not in gos:
            gos[cols[1]] = [cols[3], cols[2]] # GO accession -> [ domain, description ]
        if cols[0] not in gene_2_go:
            gene_2_go[cols[0]] = set()
        if cols[1] not in gene_2_go[cols[0]]:
            gene_2_go[cols[0]].add(cols[1])

    # Write nodes
    go_nodes_file = open(os.path.join(opts['output'], 'neo4j', 'import', 'go_nodes.csv'), "w")
    go_nodes_file.write("accession;domain;description\n")
    for accession, values in gos.iteritems():
        go_nodes_file.write(";".join([accession, values[0], values[1]]) + "\n")
    go_nodes_file.close()

    # Write edges
    go_edges_file = open(os.path.join(opts['output'], 'neo4j', 'import', 'go_edges.csv'), "w")
    go_edges_file.write("identifier;accession\n")
    for identifier, accessions in gene_2_go.iteritems():
        for accession in accessions:
            go_edges_file.write(";".join([identifier, accession]) + "\n")
    go_edges_file.close()


@job("Start neo4j docker")
def start_neo4j_docker(opts):
    '''
    Starts neo4j docker 

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    neowd =  os.path.join(opts['output'], 'neo4j')
    neowd = os.path.abspath(neowd)
    p = subprocess.call("start_neo4j_docker.sh", shell=True, env=dict(os.environ, NEOWD=neowd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p != 0:
        raise Exception("docker run command failed, error code %s" % p)
    time.sleep(15)
    utilities.netcutter_msg("Neo4j database available at 0.0.0.0:7474")


@job("Upload gene nodes to neo4j")
def upload_neo4j_genes(opts, graph):
    '''
    Uploads csv with node information onto neo4j

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    cypher = """
        LOAD CSV WITH HEADERS FROM "file:///var/lib/neo4j/import/nodes.csv" AS row
        CREATE (n:GENE)
        SET n = row
        REMOVE n.gene;
    """
    graph.run(cypher)



@job("Upload gene interactions to neo4j")
def upload_neo4j_interactions(opts, graph):
    '''
    Uploads csv with node information onto neo4j

    Args:
        opts: config options dictionary.
        graph: Graph object of neo4j database.

    Returns:
        None
    '''
    cypher = """
        LOAD CSV WITH HEADERS FROM "file:///var/lib/neo4j/import/edges.csv" AS row
        FIELDTERMINATOR ';'
        WITH EXTRACT(sc IN split(row.string_score, ",") | toString(sc)) AS string_score,  
         EXTRACT(sc in split(row.ppaxe_score, ",")  | toString(sc)) AS ppaxe_score,  
         split(row.biogrid_pubmedid, ",") AS biogrid_pubmedid,  
         split(row.string_pubmedid, ",")  AS string_pubmedid , 
         split(row.ppaxe_pubmedid, ",")   AS ppaxe_pubmedid,  
         split(row.string_evidence, ",")  AS string_evidence, 
         row as row
        MATCH (f:GENE {identifier: row.gene_1})
        MATCH (t:GENE {identifier: row.gene_2})
        CREATE (f)-[r:INTERACTS_WITH]->(t)
        SET 
          r.level = toInteger(row.level),
          r.strength = toInteger(row.strength),
          r.genetic_interaction = toInteger(row.genetic_interaction),
          r.physical_interaction = toInteger(row.physical_interaction),
          r.unknown_interaction = toInteger(row.unknown_interaction),
          r.biogrid = toInteger(row.biogrid),
          r.ppaxe = toInteger(row.ppaxe),
          r.string = toInteger(row.string),
          r.ppaxe_score = ppaxe_score,
          r.string_score = string_score,
          r.biogrid_pubmedid = biogrid_pubmedid,
          r.ppaxe_pubmedid = ppaxe_pubmedid,
          r.string_pubmedid = string_pubmedid,
          r.string_evidence = string_evidence;
    """
    graph.run(cypher)


@job("Upload gene ontologies to neo4j")
def upload_neo4j_go(opts, graph):
    '''
    Uploads csv with gene ontologies

    Args:
        opts: config options dictionary.
        graph: Graph object of neo4j database.

    Returns:
        None
    '''
    cypher = """
        LOAD CSV WITH HEADERS FROM "file:///var/lib/neo4j/import/go_nodes.csv" AS row
        FIELDTERMINATOR ';'
        CREATE (go:GO)
        SET go = row;
    """
    graph.run(cypher)

    cypher = """
        LOAD CSV WITH HEADERS FROM "file:///var/lib/neo4j/import/go_edges.csv" AS row
        FIELDTERMINATOR ';'
        MATCH (f:GENE {identifier: row.identifier})
        MATCH (t:GO {accession: row.accession})
        CREATE (f)-[r:HAS_GO]->(t)
        SET r = row;
    """
    graph.run(cypher)


@job("Shortest paths to skeleton")
def shortest_paths_to_skeleton(opts):
    '''
    Computes shortest paths from all nodes in graph to skeleton.
    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    edges_csv = os.path.join(opts['output'], 'neo4j', 'import', 'edges.csv')
    skeleton = utilities.read_skeleton(edges_csv)
    graph, vprop = utilities.read_graph(edges_csv)
    output = os.path.join(opts['output'], 'graphs', 'paths_2_skeleton.csv')
    utilities.print_shortest_paths(graph, vprop, skeleton, output)


@job("Shortest paths to csv")
def unique_shortest_path(opts):
    '''
    Gets the shortest path from each gene to drivers and skeleton.
    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    drivers = utilities.read_drivers(opts['drivers_file'])
    paths = utilities.get_paths(drivers, os.path.join(opts['output'], 'graphs', 'paths_2_skeleton.csv'))
    utilities.print_unique_paths(opts, paths)


@job("Upload shortest paths to neo4j")
def upload_neo4j_shortestpaths(opts, graph):
    '''
    Uploads csv with shortest paths

    Args:
        opts: config options dictionary.
        graph: Graph object of neo4j database.

    Returns:
        None
    '''
    cypher = """
        LOAD CSV FROM "file:///var/lib/neo4j/import/has_path.csv" AS row
        MATCH (s:GENE)
        WHERE s.identifier = row[0]
        WITH s, row
        MATCH (t:GENE)
        WHERE t.identifier = row[3]
        CREATE (p:PATHWAY {to_level: toInteger(row[1]), length: toInteger(row[2]), target:row[3]})
        CREATE (s)-[r:HAS_PATH]->(p)
        CREATE (s)-[i:IS_IN_PATH {order: 0}]->(p);
    """
    graph.run(cypher)

    cypher = """
        LOAD CSV FROM "file:///var/lib/neo4j/import/is_in_path.csv" AS row
        MATCH (g:GENE)-[has_path:HAS_PATH]->(p:PATHWAY)
        WHERE g.identifier = row[0]
        AND   p.target = row[1]
        WITH p, row
        MATCH (g:GENE)
        WHERE g.identifier = row[2]
        CREATE (g)-[is:IS_IN_PATH { order: row[3] }]->(p);
    """
    graph.run(cypher)

    cypher = """
        MATCH (n:GENE)-[r:IS_IN_PATH]->(p:PATHWAY)
        SET r.order = toInteger(r.order);
    """
    graph.run(cypher)