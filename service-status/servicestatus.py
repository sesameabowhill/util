#!/usr/bin/env python

import Queue
import re
import subprocess
import threading
import datetime

## TODO
##  - version
##  - configuration
##  - service name

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
					self.queue.task_done()
					break
			else:
				self.processor.process(record)
			self.queue.task_done()

class LogRecordProcessor:		
	def process(self, record):
		pass
	def finish(self):
		pass

class PrintLastStatus(LogRecordProcessor):
	def __init__(self):
		self.last = {}
		self.last_control = {}
	def process(self, record):
		if record.status != LogRecord.NONE:
			self.last_control[record.file] = record
		if record.date != None:
			self.last[record.file] = record
	def finish(self):
		for fn in sorted(iter(self.last)):
			last = self.last[fn]
			control = self.last_control[fn]
			print "%s: %s - [%s] (waiting from %s)" % (fn, last.date, control.status, control.date)



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
	WRAPPER_STARTED_RE = re.compile('^STATUS.*Wrapper Started')
	WRAPPER_STOPPED_RE = re.compile('^STATUS.*Wrapper Stopped')
	WAITING_LIQUIBASE_RE = re.compile('Waiting for changelog lock\.\.\.\.')



class ServerStatus:
	def start(self):
		files = ["/Users/ivan/target/logs2/md.vpc-prd-web-01.log"]
		queue = Queue.Queue();
		#processor = QueueProcessor(queue, len(files), PrintAllSystemMessages())
		processor = QueueProcessor(queue, len(files), PrintLastStatus())
		processor.start()
		threads = [ ReaderThread(fn, queue) for fn in files ]
		for thread in threads:
			thread.start()
 		#fn = "/mnt/hgfs/Share/logs2/analytics.log"
		# fn = "/mnt/hgfs/Share/logs2/uploadws.vpc-prd-ups-01.log"
		# reader = LineReader(fn)
		# for line in reader.lines():
		# 	print "==>>[%s]<<==" % line


if __name__ == "__main__":
	server_status = ServerStatus()
	server_status.start()