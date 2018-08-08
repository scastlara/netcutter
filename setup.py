import setuptools

setuptools.setup(name='netcutter',
      version='0.1',
      description='Build protein/gene interaction network relevant for a set of driver genes.',
      url='http://github.com/scastlara/netcutter',
      author='S. Castillo-Lara, R. Arenas, J.F. Abril',
      author_email='s.cast.lara@gmail.com',
      license='GPL-3.0',
      scripts=['bin/netcutter'],
      include_package_data=True,
      packages=setuptools.find_packages(),
      package_data = { 
            'netcutter' : ['bin/*.pl']},
      zip_safe=False)

