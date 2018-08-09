import setuptools

setuptools.setup(name='netcutter',
      version='0.1',
      description='Build protein/gene interaction network relevant for a set of driver genes.',
      url='http://github.com/scastlara/netcutter',
      author='S. Castillo-Lara, R. Arenas, J.F. Abril',
      author_email='s.cast.lara@gmail.com',
      license='GPL-3.0',
      scripts=['bin/netcutter', 'bin/filter_interactions_to_graph.pl', 'bin/edge2neo4jcsv.pl', 'bin/node2neo4jcsv.pl', 'bin/start_neo4j_docker.sh'],
      include_package_data=True,
      packages=setuptools.find_packages(),
      #package_data = { 
      #      'netcutter' : ['']},
      zip_safe=False)

