#!/usr/bin/env python

import Queue
import re
import subprocess
import threading
import datetime
import optparse
import sys
#import argparse


## TODO
##  - service name
##  - find restarts
##  - wait for start

class LogRecord:
	def __init__(self, line, fn, date, status):
		self.line = line
		self.file = fn
		self.date = date
		self.status = status

	NONE = "NONE"
	STARTED = "STARTED"
	WRAPPER_STARTED = "WRAPPER_STARTED"
	WRAPPER_STOPPED = "WRAPPER_STOPPED"
	WAITING_LIQUIBASE = "WAITING_LIQUIBASE"
#STATUS | wrapper  | 2012/08/01 03:12:37 | <-- Wrapper Stopped
#STATUS | wrapper  | 2012/08/01 03:12:38 | --> Wrapper Started as Daemon
#INFO   | jvm 1    | 2012/09/04 23:09:59 | 23:09:59.356 [WrapperSimpleAppMain:DB=] INFO  o.e.jetty.server.AbstractConnector - Started @0.0.0.0:82
#INFO   | jvm 1    | 2012/08/01 03:01:37 | Waiting for changelog lock....


#INFO   | jvm 1    | 2012/11/02 00:15:32 | 00:15:32.838 [WrapperSimpleAppMain:DB=] INFO  c.s.util.ArtifactInfoReporter - artifact->buildInformation buildTag: jenkins-web-do-release-62, buildId: 2012-11-01_18-33-43, buildUrl: https://jenkins.sesamecom.com/job/web-do-release/62/, gitBranch: release, gitCommit: 45c8ef110e113c24b01c4e5125d0ce9c94c51ff9, applicationName: patient-pages-1.2.92, applicationVersion: 1.2.92
#INFO   | jvm 1    | 2012/10/24 19:18:05 | 19:18:05.752 [WrapperSimpleAppMain] WARN  c.s.util.ArtifactInfoReporter - can't report version: /META-INF/MANIFEST.MF is not found in classpath
#INFO   | jvm 1    | 2012/10/19 23:38:22 | 23:38:22.741 [WrapperSimpleAppMain:DB=] INFO  o.e.jetty.webapp.WebInfConfiguration - Extract jar:file:/home/sites/artifacts/md-test-20121019.222117-32-jetty-console.war!/ to /var/tmp/jetty-0.0.0.0-82-md-test-20121019.222117-32-jetty-console.war-_-any-/webapp



#INFO   | jvm 1    | 2012/10/24 19:19:55 | 19:19:55.474 [WrapperSimpleAppMain] INFO  c.sesamecom.config.EnvironmentConfig - property->resolved name: janitorCleanupAlarmName, value: 'va-iet-web-01_cleanupAlarm', source: FILE, configFilePath: /home/sites/wrapper/conf/janitor/sesame.properties
#INFO   | jvm 1    | 2012/10/24 19:18:00 | 19:18:00.324 [WrapperSimpleAppMain] WARN  c.sesamecom.config.EnvironmentConfig - optionalProperty->defaultValueUsed name: useBasicDataSource, defaultValue: false, configFilePath: /home/sites/wrapper/conf/janitor/sesame.properties
#INFO   | jvm 1    | 2012/10/19 23:38:53 | 23:38:53.323 [WrapperSimpleAppMain:DB=] WARN  c.sesamecom.config.EnvironmentConfig - optionalProperty->defaultValueUsed name: useBasicDataSource, defaultValue: false, configFilePath: [none defined via -DsesameConfigurationFile]
#INFO   | jvm 1    | 2012/10/19 23:38:55 | 23:38:55.163 [WrapperSimpleAppMain:DB=] INFO  c.sesamecom.config.EnvironmentConfig - property->resolved name: persistSchema, value: 'sesame_stage_db', source: SYSTEM, configFilePath: [none defined via -DsesameConfigurationFile]


class QueueProcessor(threading.Thread):
	def __init__(self, queue, exit_after, processor):
		threading.Thread.__init__(self)
		self.queue = queue
		self.exit_after = exit_after
		self.processor = processor
	def run(self):
		while True:
			record = self.queue.get()
			if record == None:
				self.exit_after -= 1
				if self.exit_after == 0:
					self.processor.finish()
					#self.queue.task_done()
					break
			else:
				self.processor.process(record)
			#self.queue.task_done()

class LogRecordProcessor:		
	def process(self, record):
		pass
	def finish(self):
		pass

class FindPropertiesProcessor(LogRecordProcessor):
	def __init__(self, file_name):
		self.file_name = file_name
		self.properties = {}
	def process(self, record):
		if record.status == LogRecord.NONE:
			matched_property = FindPropertiesProcessor.PROPERTY_RE.search(record.line)
			if matched_property:
				name = matched_property.group('name').rstrip(',')
				source = matched_property.group('source')
				if source != None:
					source = source.rstrip(',')
				if source == 'FILE':
					source = matched_property.group('config').rstrip(',')
				if matched_property.group('value') == None:
					value = matched_property.group('default').rstrip(',')
					source = 'DEFAULT'
				else:
					value = matched_property.group('value').rstrip(',')
				self.properties[name] = (value, source)

		elif record.status == LogRecord.WRAPPER_STARTED:
			self.properties = {}
	def finish(self):
		for name in sorted(iter(self.properties)):
			print "%s: property %s = %s (from %s)" % (self.file_name, name, self.properties[name][0], self.properties[name][1])

	PROPERTY_RE = re.compile('EnvironmentConfig\\b.*\\b(?:resolved|defaultValueUsed)\s+' +
		'name:\s+(?P<name>\S+)\s+' +
		'(?:value:\s+(?P<value>\S+)\s+source:\s+(?P<source>\S+)|defaultValue:\s+(?P<default>\S+))\s+' +
		'configFilePath:\s+(?P<config>\S+)')

class FindVersionProcessor(LogRecordProcessor):
	def __init__(self, file_name):
		self.file_name = file_name
		self.version = None
		self.version_source = None
	def process(self, record):
		if record.status == LogRecord.NONE:
			version = None
			matched_version = FindVersionProcessor.VERSION_RE.search(record.line)
			if matched_version:
				version = matched_version.group('version').rstrip(',')
				self.version_source = FindVersionProcessor.SOURCE_ARTIFACT
			elif self.version_source in (None, FindVersionProcessor.SOURCE_JETTY):
				matched_jetty_version = FindVersionProcessor.VERSION_JETTY_RE.search(record.line)
				if matched_jetty_version:
					version = matched_jetty_version.group('version')
					self.version_source = FindVersionProcessor.SOURCE_JETTY
			if version != None:
				matched_number = FindVersionProcessor.VERSION_NAME_RE.search(version)
				if matched_number:
					self.version = (matched_number.group('number'), matched_number.group('name'))
				else:
					self.version = (version, None);
		elif record.status == LogRecord.WRAPPER_STARTED:
			self.version = None
			self.version_source = None
	def finish(self):
		if self.version != None:
			if self.version[1] == None:
				print "%s: version - %s" % (self.file_name, self.version[0])
			else:
				print "%s: version - %s (service %s)" % (self.file_name, self.version[0], self.version[1])

	SOURCE_JETTY = "jetty"
	SOURCE_ARTIFACT = "artifact"
	VERSION_RE = re.compile('ArtifactInfoReporter\\b.*\\bapplicationName:\s+(?P<version>\S+)')
	VERSION_NAME_RE = re.compile('^(?P<name>.*?)-(?P<number>\d+\.\d+\.\d+|(?:f-)?\w+-\d+\.\d+-\d+)$')
	VERSION_JETTY_RE = re.compile('WebInfConfiguration\\b.*\\bfile:[^!]+/(?P<version>\S+)-jetty-console.war!')


class FindLastStatus(LogRecordProcessor):
	def __init__(self, file_name):
		self.file_name = file_name
		self.last = None
		self.control = None
	def process(self, record):
		if record.status != LogRecord.NONE:
			self.control = record
		if record.date != None:
			self.last = record
	def finish(self):
		if self.control == None:
			print "%s: %s" % (self.file_name, self.last.date)
		else:
			print "%s: %s - [%s] (in this state from %s)" % (self.file_name, self.last.date, self.control.status, self.control.date)

class PerFileProcessors(LogRecordProcessor):
	def __init__(self, *processors):
		self.per_file = {}
		self.processors = processors
	def process(self, record):
		if record.file not in self.per_file:
			self.per_file[record.file] = [ processor(record.file) for processor in self.processors ] 
		for processor in self.per_file[record.file]:
			processor.process(record)
	def finish(self):
		for file_name in sorted(iter(self.per_file)):
			for processor in self.per_file[file_name]:
				processor.finish()

class PrintAllSystemMessages(LogRecordProcessor):
	def process(self, record):
		if record.status != LogRecord.NONE:
			print "%s [%s]: %s" % (record.date, record.status, record.line)

class LineReader:
	def __init__(self, fn):
		self.pipe = subprocess.Popen(["cat", fn], stdout=subprocess.PIPE)
	def lines(self):
		for element in self.pipe.communicate():
			if element != None:
				lines = element.split("\n")
				for line in lines:
					yield line

class ReaderThread(threading.Thread):
	def __init__(self, fn, queue):
		threading.Thread.__init__(self)
		self.reader = LineReader(fn)
		self.queue = queue
		self.file = fn
	def run(self):
		for line in self.reader.lines():
			matched_date = ReaderThread.DATE_RE.search(line)
			if matched_date:
				date = datetime.datetime(*[ int(i) for i in matched_date.groups() ])
			else:
				date = None

			if ReaderThread.STARTED_RE.search(line):
				status = LogRecord.STARTED
			elif ReaderThread.WRAPPER_STARTED_RE.search(line):
				status = LogRecord.WRAPPER_STARTED
			elif ReaderThread.WRAPPER_STOPPED_RE.search(line):
				status = LogRecord.WRAPPER_STOPPED
			elif ReaderThread.WAITING_LIQUIBASE_RE.search(line):
				status = LogRecord.WAITING_LIQUIBASE
			else:
				status = LogRecord.NONE

			self.queue.put(LogRecord(line, self.file, date, status))
		self.queue.put(None)
	DATE_RE = re.compile('(\d+)[/-](\d+)[/-](\d+)\s+(\d+):(\d+):(\d+)')
	STARTED_RE = re.compile('Started @\d+\.\d+\.\d+\.\d+:\d+')
	WRAPPER_STARTED_RE = re.compile('^STATUS\\b.*\\bWrapper Started|^STATUS\\b.*\\bLaunching a JVM')
	WRAPPER_STOPPED_RE = re.compile('^STATUS\\b.*\\bWrapper Stopped|^STATUS\\b.*\\bJVM process is gone')
	WAITING_LIQUIBASE_RE = re.compile('Waiting for changelog lock\.\.\.\.')



class ServerStatus:
	def start(self, files):
		#files = ["/Users/ivan/target/logs2/md.vpc-prd-web-01.log", "/Users/ivan/target/logs2/uploadws.vpc-prd-ups-01.log"]
		# files = ["/Users/ivan/target/logs2/started.log", "/Users/ivan/target/logs2/started2.log", \
		# 	"/Users/ivan/target/logs2/waiting.log", "/Users/ivan/target/logs2/wrapper_started.log"]
		queue = Queue.Queue();
		#processor = QueueProcessor(queue, len(files), PrintAllSystemMessages())
		#processor = QueueProcessor(queue, len(files), PerFileProcessors(FindLastStatus))
		processor = QueueProcessor(queue, len(files), PerFileProcessors(FindLastStatus, FindVersionProcessor, FindPropertiesProcessor))
		processor.start()
		threads = [ ReaderThread(fn, queue) for fn in files ]
		for thread in threads:
			thread.start()

		processor.join()
 		#fn = "/mnt/hgfs/Share/logs2/analytics.log"
		# fn = "/mnt/hgfs/Share/logs2/uploadws.vpc-prd-ups-01.log"
		# reader = LineReader(fn)
		# for line in reader.lines():
		# 	print "==>>[%s]<<==" % line


#import yappi

if __name__ == "__main__":
	# parser = argparse.ArgumentParser(description='Watch log files.')
	# parser.add_argument('files', type=str, nargs='+', help='Log file to watch')
	# args = parser.parse_args()
	parser = optparse.OptionParser()
	parser.add_option("-f", "--file", dest="files", help="Log file to watch")
	(options, args) = parser.parse_args()
	if len(args) == 0:
		print "need at least one file name"
		sys.exit(1)

	#yappi.start()

	server_status = ServerStatus()
	server_status.start(args)

	#yappi.print_stats()
