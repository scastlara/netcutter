import setuptools


setuptools.setup(name='netcutter',
      version='1.2',
      description='Disentangle protein-protein interaction networks using a list of genes as drivers.',
      url='http://github.com/scastlara/netcutter',
      author='S. Castillo-Lara',
      author_email='s.cast.lara@gmail.com',
      license='GPL-3.0',
      scripts=['bin/netcutter'],
      include_package_data=True,
      packages=setuptools.find_packages(),
      zip_safe=False)

