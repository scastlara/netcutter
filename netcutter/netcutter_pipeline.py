from .job_list import *

class NetcutterPipeline(object):

    _job_list = [
        JobCreateDirectories
    ]

    def __init__(self, options):
        self.options = options
        self._job_name_mappings = None
    
    def run(self):
        for job_class in self.jobs_to_run():
            job = job_class(self.options)
            job.run()
    
    def jobs_to_run(self):
        if self.logfile_exists():
            return self._read_jobs_to_run()
        else:
            return NetcutterPipeline._job_list
    
    def logfile_exists(self):
        return os.path.isfile(self.options.logfile)
    
    @property
    def job_name_mappings(self):
        if not self._job_name_mappings:
            self._job_name_mappings = {}
            for job in NetcutterPipeline._job_list:
                self._job_name_mappings[job.__name__] = job
        return self._job_name_mappings

    def _read_jobs_to_run(self):
        log_filehandle = self.options.get_log_filehandle()
        done_job_names = self._read_done_jobs(log_filehandle)
        log_filehandle.close()
        return self._get_jobs_from_names(done_job_names, reverse=True)

    def _read_done_jobs(self, log_filehandle):
        current_job = ""
        done_job_names = []
        for line in log_filehandle:
            line = line.strip()
            if line.startswith("Job"):
                _, job_name = line.split(": ")
                current_job = job_name
            elif line.startswith("Status"):
                _, status = line.split(": ")
                if status == "status.done":
                    done_job_names.append(current_job)
            else:
                continue
        return done_job_names

    def _get_jobs_from_names(self, job_names, reverse=False):
        jobs = []
        all_job_names = self.job_name_mappings.keys()
        for job_name in all_job_names:
            if reverse:
                if job_name in job_names:
                    continue
            else:
                if job_name not in job_names:
                    continue
            jobs.append(self.job_name_mappings[job_name])
        return jobs
