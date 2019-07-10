from .job_list import *

class JobScheduler(object):
    """
    Handles the list of jobs of NetcutterPipeline: its elements and the updates.

    Attributes:
        job_list (list): List of "Job" classes.
        _job_name_mappings (dict): Dictionary mapping job names to job classes.
    """
    
    def __init__(self):
        self.job_list = [
            CreateDirectories,
            BuildGraph,
            #EdgesToCsv,
            #NodesToCsv,
        ]
        self._job_name_mappings = {}
    
    @property
    def job_name_mappings(self):
        if not self._job_name_mappings:
            for job in self.job_list:
                self._job_name_mappings[job.__name__] = job
        return self._job_name_mappings

    def remove_jobs_before_start(self, start_job):
        job_names = [ job.__name__ for job in self.job_list ]
        try:
            start_job_index = job_names.index(start_job)
            self.job_list = self.job_list[start_job_index:]
        except ValueError:
            pass
        return self.job_list

    def remove_jobs_after_stop(self, stop_job):
        job_names = [ job.__name__ for job in self.job_list ]
        try:
            stop_job_index = job_names.index(stop_job)
            self.job_list = self.job_list[:stop_job_index + 1]
        except ValueError:
            pass
        return self.job_list

    def read_jobs_to_run(self, options):
        log_filehandle = options.get_log_filehandle()
        done_job_names = self._read_done_jobs(log_filehandle)
        log_filehandle.close()
        not_done_jobs = self._get_not_done_jobs(done_job_names)
        self.job_list = not_done_jobs
    
    def keep_jobs_with_tags(self, tags):
        self.job_list = [ job for job in self.job_list if job.tags in tags ]

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

    def _get_done_jobs(self, done_job_names):
        return self._get_jobs_from_names(done_job_names)

    def _get_not_done_jobs(self, done_job_names):
        return self._get_jobs_from_names(done_job_names, reverse=True)
    
    def _get_jobs_from_names(self, job_names, reverse=False):
        jobs = []
        all_job_names = [ job.__name__ for job in self.job_list ]
        for job_name in all_job_names:
            if reverse:
                if job_name not in job_names:
                    jobs.append(self.job_name_mappings[job_name])
            else:
                if job_name in job_names:
                    jobs.append(self.job_name_mappings[job_name])
        return jobs