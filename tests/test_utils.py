from netcutter import *
import os
import pytest

@pytest.fixture
def rootdir():
    return os.path.dirname(os.path.abspath(__file__))

@pytest.fixture
def options():
    rootdir = os.path.dirname(os.path.abspath(__file__))
    conf_file = os.path.join(rootdir, 'test_files/netcutter.conf')
    return NetcutterOptions.from_config_file(conf_file)


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
            "tags",
            "stop_at",
            "start_at",
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

def test_read_conf(options):
    assert(options.project_name == "PROJECT_NAME_HERE")

def test_get_done_jobs(options):
    pipeline = NetcutterPipeline(options)
    job_name = "CreateDirectories"
    jobs = pipeline.job_scheduler._get_done_jobs([job_name])
    assert(jobs[0].__name__ == job_name)

def test_get_not_done_jobs(options):
    pipeline = NetcutterPipeline(options)
    job_name = "CreateDirectories"
    all_job_names = set([ job.__name__ for job in pipeline.job_list ])
    not_done_jobs = pipeline.job_scheduler._get_not_done_jobs([job_name])
    not_done_jobs = set([ job.__name__ for job in not_done_jobs ])
    
    assert(job_name not in not_done_jobs) # job_name is done, so it should not be in not_done_jobs
    assert(len(all_job_names) - 1 == len(not_done_jobs))

def test_tags(options):
    options.tags = set(["build"])
    pipeline = NetcutterPipeline(options)
    jobs_to_run = pipeline.jobs_to_run()
    job_names = [ job.__name__ for job in jobs_to_run ]
    assert(job_names == ["CreateDirectories", "BuildGraph"])

def test_start_at(options):
    options.start_at = "BuildGraph"
    pipeline = NetcutterPipeline(options)
    all_jobs = pipeline.job_scheduler.job_list
    jobs_to_run = pipeline.jobs_to_run()
    assert(len(all_jobs) == len(jobs_to_run) + 1)

def test_stop_at(options):
    options.stop_at = "BuildGraph"
    pipeline = NetcutterPipeline(options)
    jobs_to_run = pipeline.jobs_to_run()
    assert(len(jobs_to_run) == 2)

def test_no_jobs_to_run(options):
    options.tags = set(["build"])
    options.start_at = "NodesToCsv"
    pipeline = NetcutterPipeline(options)
    
    try:
        pipeline.jobs_to_run()
        assert(1 == 0)
    except ValueError:
        assert(1 == 1)