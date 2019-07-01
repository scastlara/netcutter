from enum import Enum
import sys
import textwrap
import datetime

class Job(object):
    """

    Example:

from netcutter.netcutter_options import NetcutterOptions
from netcutter.netcutter_pipeline import *
op = NetcutterOptions.from_config_file("netengine.conf")
pipe = NetcutterPipeline(op)
pipe.run()
    """
    
    _status = Enum("status", "prepared done error")

    def __init__(self, options):
        self.options = options
        self.status = Job._status.prepared
        self.error_message = None
        self.start_time = None
        self.end_time = None
    
    @property
    def name(self):
        return str(self.__class__.__name__)

    @property
    def elapsed_time(self):
        if self.has_finished():
            duration = self.start_time - self.end_time
            return str(duration)
        else:
            return "-"

    def run(self):
        try:
            self.start_time = datetime.datetime.now()
            self._run()
            self._define_done()
        except Exception as err:
            self._define_error(err)
        finally:
            self.end_time = datetime.datetime.now()
            self.log()
            self.exit_if_error()
    
    def _run(self):
        raise NotImplementedError("Must use specific Job instead of base Job class!")

    def log(self):
        log_filehandle = self.options.get_log_filehandle("a")
        log_filehandle.write(str(self))
        log_filehandle.close()

    def _define_error(self, error_message):
        self.status = Job._status.error
        self.error_message = error_message

    def _define_done(self):
        self.status = Job._status.done
        self.error_message = None

    def has_finished(self):
        return self.status == self._status.done
    
    def has_error(self):
        return self.status == self._status.error

    def exit_if_error(self):
        if self.has_error():
            sys.exit(1)

    def format_error_message(self):
        if self.has_error():
            return "{}".format(self.error_message)
        else:
            return "-"
            
    def __str__(self):
        return textwrap.dedent("""
            ---
            Job: {0}
            Status: {1}
            Start time: {2}
            End time: {3}
            Elapsed time: {4}
            Error: {5}
            """.format(
                self.name, 
                self.status.name, 
                self.start_time, 
                self.end_time, 
                self.elapsed_time,
                self.format_error_message()
            )
        )
