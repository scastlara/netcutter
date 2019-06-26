from netcutter import *
import os
import pytest

@pytest.fixture
def rootdir():
    return os.path.dirname(os.path.abspath(__file__))

def test_netcutter_options_creation():
    try:
        options = NetcutterOptions()
        assert(1 == 1)
    except Exception:
        assert(1 == 0)

def test_netcutter_options_parameters():
    expected_parameters = set(
        [
            "logfile",
            "project_name",
            "output",
            "neo4j_memory",
            "neo4j_address",
            "biogrid_file",
            "string_file",
            "ppaxe_file",
            "drivers_file",
            "alias_file",
            "web_address",
            "content_template",
            "logo_img",
            "download_databases",
            "drivers_ext",
            "nvariants_file",
            "gene_ontology_file",
            "download_gene_ontology",
        ]
    )
    options = NetcutterOptions()
    real_parameters = set(options.__dict__.keys())
    assert(expected_parameters == real_parameters)

def test_read_conf(rootdir):
    conf_file = os.path.join(rootdir, 'test_files/netcutter.conf')
    options = NetcutterOptions.from_config_file(conf_file)
    assert(options.project_name == "PROJECT_NAME_HERE")

    