from .job_scheduler import *

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
        self.handle_tags()
        self.handle_start_at()
        self.handle_stop_at()
        self.handle_done_jobs()
        
        self.exit_if_no_jobs()
        return self.job_list
    
    def log(self, message, exit_flag=False):
        header = "Warning"
        if exit_flag:
            header = "Error"
        log_filehandle = self.options.get_log_filehandle(mode="w")
        log_filehandle.write("{}: {}\n".format(header, message))
        log_filehandle.close()
        if exit_flag:
            sys.exit(1)

    def logfile_exists(self):
        return os.path.isfile(self.options.logfile)

    def handle_tags(self):
        if self.options.tags is not None:
            self.job_scheduler.keep_jobs_with_tags(self.options.tags)

    def handle_start_at(self):
        if self.options.start_at is not None:
            self.job_scheduler.remove_jobs_before_start(self.options.start_at)

    def handle_stop_at(self):
        if self.options.stop_at is not None:
            self.job_scheduler.remove_jobs_after_stop(self.options.stop_at)

    def handle_done_jobs(self):
        if self.logfile_exists():
            self.job_scheduler.read_jobs_to_run(self.options)

    def exit_if_no_jobs(self):
        if not self.job_list:
            self.log("No jobs to run.", exit_flag=True)