from .job_scheduler import *
import sys

class NetcutterPipeline(object):

    def __init__(self, options):
        self.options = options
        self.job_scheduler = JobScheduler()

    @property
    def job_list(self):
        return self.job_scheduler.job_list

    def run(self):
        for job_class in self.jobs_to_run():
            job = job_class(self.options)
            job.run()
    
    def jobs_to_run(self):
        self._handle_tags()
        self._handle_start_at()
        self._handle_stop_at()
        self._handle_done_jobs()
        
        self._exit_if_no_jobs()
        return self.job_list
    
    def log(self, message, exception=None):
        header = "Warning"
        if exception is not None:
            header = "Error"
        log_filehandle = self.options.get_log_filehandle(mode="w")
        log_filehandle.write("{}: {}\n".format(header, message))
        log_filehandle.close()
        if exception is not None:
            raise exception(message)

    def logfile_exists(self):
        return os.path.isfile(self.options.logfile)

    def _handle_tags(self):
        if self.options.tags is not None:
            self.job_scheduler.keep_jobs_with_tags(self.options.tags)

    def _handle_start_at(self):
        if self.options.start_at is not None:
            try:
                self.job_scheduler.remove_jobs_before_start(self.options.start_at)
            except ValueError:
                self.log("Invalid option for 'start_at': {}".format(self.options.start_at), ValueError)

    def _handle_stop_at(self):
        if self.options.stop_at is not None:
            try:
                self.job_scheduler.remove_jobs_after_stop(self.options.stop_at)
            except ValueError:
                self.log("Invalid option for 'stop_at': {}".format(self.options.stop_at), ValueError)

    def _handle_done_jobs(self):
        if self.logfile_exists():
            self.job_scheduler.read_jobs_to_run(self.options)

    def _exit_if_no_jobs(self):
        if not self.job_list:
            self.log("No jobs to run.", exception=IndexError)