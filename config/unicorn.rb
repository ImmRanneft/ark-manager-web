WORKING_DIR = File.dirname(File.expand_path('..', __FILE__))
working_directory WORKING_DIR

stderr_path WORKING_DIR + "/log/unicorn.stderr.log"
stdout_path WORKING_DIR + "/log/unicorn.stderr.log"

pid WORKING_DIR + "/tmp/unicorn.pid"

listen '127.0.0.1:8080'
