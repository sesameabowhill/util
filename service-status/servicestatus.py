#!/usr/bin/env python

import subprocess
import threading

class LineReader:
	def __init__(self, file):
		self.pipe = subprocess.Popen(["cat", file], stdout=subprocess.PIPE)
	def lines(self):
		for element in self.pipe.communicate():
			if element != None:
				lines = element.split("\n")
				for line in lines:
					yield line

class ReaderThread(threading.Thread):
	def __init__(self, file):
		threading.Thread.__init__(self)
		self.reader = LineReader(file)
	def run(self):
		for line in self.reader.lines():
			print "==>>[%s]<<==" % line


class ServerStatus:
	def start(self):
		t1 = ReaderThread("a.txt")
		t2 = ReaderThread("b.txt")
		t3 = ReaderThread("c.txt")
		t4 = ReaderThread("d.txt")
		t5 = ReaderThread("e.txt")
		t1.start()
		t2.start()
		t3.start()
		t4.start()
		t5.start()
		#fn = "/mnt/hgfs/Share/logs2/analytics.log"
		# fn = "/mnt/hgfs/Share/logs2/uploadws.vpc-prd-ups-01.log"
		# reader = LineReader(fn)
		# for line in reader.lines():
		# 	print "==>>[%s]<<==" % line


if __name__ == "__main__":
	server_status = ServerStatus()
	server_status.start()