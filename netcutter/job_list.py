from .job import Job
import os
import sys
from subprocess import call

class CreateDirectories(Job):
    """
    """
    _directories = [
        'plots', 
        'graphs', 
        'tables', 
        'django-project', 
        'logs', 
        'databases', 
        'GO',
        'neo4j', 
        os.path.join('neo4j', 'import'), 
        os.path.join('neo4j', 'data'), 
        os.path.join('neo4j', 'logs'), 
        os.path.join('neo4j', 'conf')
    ]

    tags = set(["build"])
    
    def __init__(self, options):
        super(CreateDirectories, self).__init__(options)

    def _run(self):
        for directory in CreateDirectories._directories:
            self._create_directory(directory)

    def _create_directory(self, directory):
        permissions = 0o777
        os.mkdir(os.path.join(self.options.output, directory), permissions, exist_ok=True)


class BuildGraph(Job):
    """
    """

    tags = set(["build"])

    def __init__(self, options):
        super(BuildGraph, self).__init__(options)

    def _run(self):
        call(self._prepare_command())

    def _prepare_command(self):
        cmd = []
        cmd.append("filter_interactions_to_graph.pl")
        drivers_type = "ids"
        if self.options.drivers_ext:
            drivers_type = "ext"
        cmd.append("{}:{}".format(drivers_type, self.options.drivers_file))
        cmd.append(self.options.alias_file)
        cmd.append(os.path.join(self.options.output, "graphs", "graphs"))
        graph_files = [
            graphname 
            for graphname in ("biogrid_file", "string_file", "ppaxe_file") 
            if graphname in self.options.getattr(graphname)
        ]
        graph_names = [ gfile.replace("_file", "") for gfile in graph_files ]
        for name, file_name in zip(graph_names, graph_files):
            subcmd = "{}:{}".format(name, self.options.getattr(file_name))
            cmd.append(subcmd)
        return cmd


class EdgesToCsv(Job):

    tags = set(["neo4j"])
    
    def __init__(self, options):
        super(EdgesToCsv, self).__init__(options)

    def _run(self):
        call(self._prepare_command())
    
    def _prepare_command(self):
        pass


class NodesToCsv(Job):

    tags = set(["neo4j"])

    def __init__(self, options):
        super(NodesToCsv, self).__init__(options)

    def _run(self):
        call(self._prepare_command())
    
    def _prepare_command(self):
        pass


# Add new jobs here.