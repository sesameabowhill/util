import sublime, sublime_plugin, re, time, json
from datetime import datetime, timedelta

from AwsApiCall import AwsApiCall
from UploadApiCall import UploadApiCall

class CallExternalApiCommand(sublime_plugin.TextCommand):
	def run(self, edit):
		apis = { 'swf' : AwsApiCall, 'upload' : UploadApiCall, 'client' : UploadApiCall }
		api_cache = {}
		commands = []
		for line in self.get_all_lines(self.view.sel()):
			command = self.find_command(line)
			if command:
				commands.append((line, command))
				command_group = command[0]
				if command_group in apis:
					if not command_group in api_cache:
						api_cache[command_group] = apis[command_group](self)
				else:
					self.report_error("unknown group [%s]" % command_group)

		call_thread = CallThread(self, edit, commands, api_cache)
		call_thread.start()
		#call_thread.join()
		#call_thread.run()
		results = call_thread.get_results()
		self.view.sel().clear()
		# for result in results:
		# 	self.insert_result(result[0], edit, result[1])

	def insert_result(self, line, edit, result):
		line_region = self.view.line(self.view.text_point(line, 0))
		line_text = self.view.substr(line_region)
		line_text = CallExternalApiCommand.CLEAR_RESULT_RE.sub('', line_text)
		line_text += ' -> '
		start_column = len(line_text)
		line_text += str(result)
		end_column = len(line_text)
		self.view.replace(edit, line_region, line_text)
		self.view.sel().add(sublime.Region(self.view.text_point(line, start_column), self.view.text_point(line, end_column)))

	def find_access_keys(self, key_param, secret_param):
		access_key = None
		secret_key = None
		access_key_line = self.view.find(key_param, 0)
		secret_key_line = self.view.find(secret_param, 0)
		if access_key_line != None:
			found = self.get_setting_value(access_key_line)
			if found != None:
				access_key = found[1]
		if secret_key_line != None:
			found = self.get_setting_value(secret_key_line)
			if found != None:
				secret_key = found[1]
		if access_key != None and secret_key != None:
			return (access_key, secret_key)
		else:
			return None

	def get_all_lines(self, regions):
		lines = {}
		for region in regions:
			begin = self.view.rowcol(region.begin())
			end = self.view.rowcol(region.end())
			for line in range(begin[0], end[0] + 1):
				lines[line] = 1
		return lines.keys()

	def find_command(self, line):
		line_text = self.view.substr(self.view.line(self.view.text_point(line, 0)))
		matched = CallExternalApiCommand.COMMAND_RE.search(line_text)
		if matched:
			params = matched.group('params')
			if params == None:
				params = []
			else:
				params = CallExternalApiCommand.CLEAR_RESULT_RE.sub('', params)
				if len(params.strip()):
					params = [ p.strip() for p in re.split(',|\s+', params) ]
			return (matched.group('service'), matched.group('command'), params)
		else:
			return None

	def get_setting_value(self, region):
		line = self.view.substr(self.view.line(region))
		matched = CallExternalApiCommand.SETTING_RE.search(line)
		if matched:
			value = matched.group('value').strip()
			file_name_matched = CallExternalApiCommand.FILE_PATH_RE.search(value)
			if file_name_matched:
				f = open(file_name_matched.group('name'), 'r')
				value = f.read().strip()
				f.close()
			return (matched.group('key'), value)
		else:
			return None

	def report_error(self, message):
		print message

	def report_info(self, message):
		print message

	FILE_PATH_RE = re.compile('^file:(?P<name>.+)')	
	CLEAR_RESULT_RE = re.compile('\s?->.*')	
	SETTING_RE = re.compile('^\s*!\s*(?:aws|internal)\s*:\s*(?P<key>[^:]+?)\s*=\s*(?P<value>\S+)')	
	COMMAND_RE = re.compile('^\s*!\s*(?P<service>[^:]+?)\s*:\s*(?P<command>[^(\s]+?)\\b(?:[\s|\(](?P<params>[^)]*)\)?)?')

class CallThread(threading.Thread):
	def __init__(self, view, edit, commands, api_cache):
		threading.Thread.__init__(self)
		self.view = view
		self.edit = edit
		self.commands = commands
		self.api_cache = api_cache
		self.results = []

	def run(self):
		total = len(self.commands)
		current = 0
		start = time.time()
		for command_line in self.commands:
			current += 1
			sublime.set_timeout(self.status_report(current, total), 10)
			command = command_line[1]
			result = self.api_cache[command[0]].get_result(command)
			if result:
				self.results.append((command_line[0], result))
				sublime.set_timeout(self.insert_result(command_line[0], result), 10)

		sublime.set_timeout(lambda: self.view.view.set_status('CallExternalApiCommand', 
			"%d call%s took %.02f seconds" % (total, ('' if total == 1 else 's'), time.time() - start)), 10)
		sublime.set_timeout(lambda: self.view.view.erase_status('CallExternalApiCommand'), 30000)

	def get_results(self):
		return self.results

	def status_report(self, current, total):
		return lambda: self.view.view.set_status('CallExternalApiCommand', "process %d of %d" % (current, total))

	def insert_result(self, line, result):
		return lambda: self.view.insert_result(line, self.edit, result)

		