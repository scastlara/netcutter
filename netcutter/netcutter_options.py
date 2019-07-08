import sys

class NetcutterOptions(object):

    _defaults = {
        "logfile" : "netcutter.log",
        "project_name" : None, 
        "output" : None,
        "start_at": None,
        "stop_at": None,
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
        self._check_options()

    def get_log_filehandle(self, mode="r"):
        return open(self.logfile, mode)

    def _check_options(self):
        """
        Checks if options are set correctly.

        Raises:
            ValueError: If option has a non-valid value.
            KeyError: If option name is not valid.
        """
        self._check_required_options()
        self._check_incompatible_options()
        self._check_non_valid_options()
    
    def _check_required_options(self):
        """
        Checks if any of the required options is None.
        """
        pass
    
    def _check_incompatible_options(self):
        """
        Checks if two (or more) incompatible are set at the same time.
        """
        pass
    
    def _check_non_valid_options(self):
        """
        Checks if a non-valid option is set.
        """
        pass

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
                if line.startswith("#") or not line:
                    continue
                try:
                    option, value = line.split("=")
                    opts[option] = value
                except ValueError:
                    sys.stderr.write("Invalid config parameter, line: {}\n".format(line))
        return opts

