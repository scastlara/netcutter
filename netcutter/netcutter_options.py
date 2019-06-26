import sys

class NetcutterOptions(object):

    _defaults = {
        "logfile" : "netcutter.log",
        "project_name" : None, 
        "output" : None, 
        "neo4j_memory" : None,
        "neo4j_address" : None,
        "biogrid_file" : None,
        "string_file" : None,
        "ppaxe_file" : None,
        "drivers_file" : None,
        "alias_file" : None,
        "web_address" : None,
        "content_template" : None,
        "logo_img" : None,
        "download_databases" : None,
        "drivers_ext" : None,
        "nvariants_file" : None,
        "gene_ontology_file" : None,
        "download_gene_ontology" : None
    }

    def __init__(self, **kwargs):
        self.__dict__.update(self._defaults)
        self.__dict__.update(kwargs)

    def get_log_filehandle(self, mode="r"):
        return open(self.logfile, mode)

    @classmethod
    def from_config_file(cls, filename):
        opts = cls.parse_config_file(filename)
        return cls(**opts)

    @classmethod
    def parse_config_file(cls, filename):
        opts = {}
        with open(filename, "r") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("#"):
                    continue
                try:
                    option, value = line.split("=")
                    opts[option] = value
                except ValueError:
                    sys.stderr.write("Invalid config parameter, line: {}".format(line))
        return opts

