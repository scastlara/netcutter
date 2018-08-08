# ---------------------------------------------------------------- #
# JOBS FOR NETCUTTER
# ---------------------------------------------------------------- #
from functools import wraps


def job(job_name):
    '''
    Decorator for jobs.
    Add @job('JOB-NAME') to a function to make it a job
    '''
    def job_decorator(func):
        @wraps(func)
        def wrapped_function(*args, **kwargs):
            print_job(job_name, done=False)
            func(*args, **kwargs)
            print_job(job_name, done=True)
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
    directories = ['plots', 'graphs', 'tables', 'django-project', 'logs', 'databases', 'neo4j']
    for direct in directories:
        try:
            os.mkdir(os.path.join(opts['output'], direct))
        except OSError as err:
            netengine_error(str(err), fatal=False)

def print_job(name, done=False):
    if done is False:
        sys.stderr.write("\n# ---------------------------------------- #\n")
        sys.stderr.write("# JOB: %s\n" % name.upper())
        sys.stderr.write("# ---------------------------------------- #\n")
        sys.stderr.write("\n     - Starting job: %s \n" % get_time())
    else:
        sys.stderr.write("\n     - Finished: %s \n\n" % get_time())


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
    cmd.append(opts['bin'] + '/' + 'filter_interactions_to_graph.pl')
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
    cmd.append(os.path.join(opts['bin'], 'edge2neo4jcsv.pl'))
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
    cmd.append(os.path.join(opts['output'], 'neo4j', 'edges.csv'))

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
    cmd.append(os.path.join(opts['bin'], 'node2neo4jcsv.pl'))
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
    cmd.append(os.path.join(opts['output'], 'neo4j', 'nodes.csv'))
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


@job("Start neo4j docker")
def start_neo4j_docker(opts):
    '''
    Starts neo4j docker 

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


@job("Start neo4j docker")
def start_neo4j_docker(opts):
    '''
    Starts neo4j docker 

    Args:
        opts: config options dictionary.

    Returns:
        None
    '''
    cmd = list()
