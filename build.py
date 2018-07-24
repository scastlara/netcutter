import sys
import os
import datetime


def print_start():
	'''
	Prints start program
	'''
	msg = """
# ------------------------------------ #
#      build.py: Building NetEngine    #
# ------------------------------------ #
    - Start: %s

""" % datetime.datetime.now().strftime("%a, %d %B %Y %H:%M:%S")
	sys.stderr.write(msg)
	return
	

def netengine_error(msg, fatal=True):
	'''
	Deals with errors
	'''
	msg_header = "\n\n# NETENGINE ERROR\n"
	if fatal is True:
		msg_header += "# [ FATAL ]\n"
		sys.exit(msg_header + "# " + msg +  "\n")
	else:
		msg_header += "# [ WARNING ]\n"
		sys.stderr.write(msg_header + "# " + msg +  "\n")
	return


def read_config(cfile):
	'''
	Reads configuration file.
	Returns option dictionary
	'''
	valid_options = set([
		"project_name","neo4j_memory","neo4j_address",
		"biogrid_file","string_file","ppaxe_file",
		"drivers_file","alias_file","web_address",
		"content_templates","logo_img"
		])
	opts = dict()
	try:
		fh = open(cfile, "r")
	except Exception:
		msg = "Config file not found. Can't read: %s" % cfile
		netengine_error(msg, fatal=True)
	for line in fh:
		line = line.strip()
		if line.startswith("#") or not line:
			continue
		opt, value = line.split("=")
		if opt not in valid_options:
			msg = "Not valid option: %s! Ignoring it..." % opt
			netengine_error(msg, fatal=False)
			continue
		if opt in opts:
			msg = "Repeated option: %s! Ignoring it..." % opt
			netengine_error(msg, fatal=False)
			continue
		opts[opt] = value
	return opts


def print_opts(opts):
	'''
	Prints options to stderr
	'''
	valid_options = [
		"project_name","neo4j_memory","neo4j_address",
		"biogrid_file","string_file","ppaxe_file",
		"drivers_file","alias_file","web_address",
		"content_templates","logo_img"
		]
	sys.stderr.write("    OPTIONS:\n")
	for opt in valid_options:
		sys.stderr.write("    - %s : %s\n" % (opt, opts[opt]) )
	return


def check_dependencies():
	'''
	Checks dependencies
	'''
	pass


def check_opts(opts):
	'''
	Checks options and sets default parameters for missing opts
	'''
	defaults = {
		'neo4j_memory': '2g', 'neo4j_address': 'localhost:7474',
		'web_address': 'localhost:8000'
		}

	for opt, default in defaults.iteritems():
		if opt not in opts:
			opts[opt] = default

	if ('biogrid_file' not in opts 
		or  'string_file' not in opts
		or 'ppaxe_file' not in opts):
		msg = "Biogrid, String or PPaxe file required!"
		netengine_error(msg, fatal=True)

	if 'drivers_file' not in opts:
		msg = "Drivers file required!"
		netengine_error(msg, fatal=True)
	return


def main():
	print_start()
	check_dependencies()
	opts = read_config(sys.argv[1])
	check_opts(opts)
	print_opts(opts)


if __name__ == "__main__":
    main()