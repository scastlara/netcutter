from .job import Job
import os
import sys

class JobCreateDirectories(Job):
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

    def _run(self):
        for directory in JobCreateDirectories._directories:
            self._create_directory(directory)

    def _create_directory(self, directory):
        permissions = 0o777
        os.mkdir(os.path.join(self.options.output, directory), permissions)


# Add new jobs here.