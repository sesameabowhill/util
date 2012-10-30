#!/usr/bin/env python

import subprocess
import threading
import Queue

class Record:
	def __init__(self, line, fn):
		self.line = line
		self.file = fn

class QueueProcessor(threading.Thread):
	def __init__(self, queue, exit_after):
		threading.Thread.__init__(self)
		self.queue = queue
		self.exit_after = exit_after
	def run(self):
		while True:
			record = self.queue.get()
			if record == None:
				self.exit_after -= 1
				if self.exit_after == 0:
					break
			else:
				print "==>>[%s]<<==" % record.line
				self.queue.task_done()

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
			self.queue.put(Record(line, self.file))
			#print "==>>[%s]<<==" % line
		self.queue.put(None)


class ServerStatus:
	def start(self):
		files = ("a.txt", "b.txt", "c.txt", "d.txt", "e.txt")
		queue = Queue.Queue();
		processor = QueueProcessor(queue, len(files))
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