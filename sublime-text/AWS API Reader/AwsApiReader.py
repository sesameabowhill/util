import sublime, sublime_plugin, re, time, json
from datetime import datetime, timedelta
import boto

import boto.swf.layer1
import boto.dynamodb.layer2

class CallAwsApiCommand(sublime_plugin.TextCommand):
	def run(self, edit):
		access = self.find_access_keys()
		if access != None:
			self.report_info("using access key %s" % access[0])
			for line in self.get_all_lines(self.view.sel()):
				command = self.find_command(line)
				if command:
					result = self.aws_command(access, command)
					if result:
						self.insert_result(line, edit, result)
		else:
			self.report_error("can't find value for access key (!aws:access_key_id=..., !aws:secret_access_key=...)")

	def aws_command(self, access, command):
		if command[0] == 'swf':
			if command[1] == 'list_domains':
				return self.swf_list_domains(access)
			elif command[1] == 'list_failed_workflows':
				return self.swf_list_closed_workflow_executions(access, command[2][0], 'FAILED')
			elif command[1] == 'workflow_status':
				return self.swf_workflow_status(access, command[2][0], command[2][1])
			else:
				self.report_error("unexpected command [%s] in [%s] service" % (command[1], command[0]))
		else:
			self.report_error("unexpected service [%s]" % command[0])
		return None

	def swf_list_domains(self, access):
		swf = boto.connect_swf(*access)
		self.report_info("list domains")
		return ', '.join(info['name'] for info in swf.list_domains('REGISTERED')['domainInfos'])

	def swf_list_closed_workflow_executions(self, access, domain, status):
		swf = boto.connect_swf(*access)
		now = datetime.utcnow()
		day_before = now - timedelta(days = 1)
		self.report_info("list %s executions in [%s], from [%sZ], to [%sZ]" % 
			(status, domain, str(day_before), str(now)))
		executions = swf.list_closed_workflow_executions(domain, 
			start_latest_date = self.convert_to_timestamp(now), 
			start_oldest_date = self.convert_to_timestamp(day_before),
			close_status = status)
		return ', '.join('%s - %s' % (execution['execution']['workflowId'], self.timestamp_to_string(execution['closeTimestamp'])) 
			for execution in executions['executionInfos'])

	def swf_workflow_status(self, access, domain, workflow_id):
		swf = boto.connect_swf(*access)
		now = datetime.utcnow()
		oldest = now - timedelta(days = 365)
		self.report_info("get workflow [%s] status, from [%sZ], to [%sZ], domain %s" % 
			(workflow_id, str(oldest), str(now), domain))
		executions = swf.list_closed_workflow_executions(domain, 
			start_latest_date = self.convert_to_timestamp(now), 
			start_oldest_date = self.convert_to_timestamp(oldest),
			workflow_id = workflow_id)
		if len(executions['executionInfos']):
			execution = executions['executionInfos'][0]
			status = execution['closeStatus']
			if status == 'FAILED':
				return "%s - %s" % (status, self.get_failed_details(swf, domain, execution['execution']))
			else:
				return "%s - %s" % (status, self.timestamp_to_string(execution['closeTimestamp']))
		return None

	def get_failed_details(self, swf, domain, execution):
		history = swf.get_workflow_execution_history(domain, execution['runId'], execution['workflowId'], reverse_order = True)
		failed_activity_events = filter(lambda event: event['eventType'] == 'ActivityTaskFailed', history['events'])
		if len(failed_activity_events):
			failed_activity_event = failed_activity_events[0]
			scheduled_id = failed_activity_event['activityTaskFailedEventAttributes']['scheduledEventId']
			scheduled_activity_events = filter(lambda event: event['eventId'] == scheduled_id, history['events'])
			failed_activity = None
			if len(scheduled_activity_events):
				scheduled_activity = scheduled_activity_events[0]['activityTaskScheduledEventAttributes']['activityType']['name']
			else:
				scheduled_activity = "Unknown"
			details = self.get_stack_trace_details(failed_activity_event['activityTaskFailedEventAttributes']['details'])
			if details == None:
				details = failed_activity_event['activityTaskFailedEventAttributes']['reason']
			details = details.replace("\n", "\\n")
			return "%s - %s" % (scheduled_activity, details)
		failed_child_workflow_events = filter(lambda event: event['eventType'] == 'ChildWorkflowExecutionFailed', history['events'])
		if len(failed_child_workflow_events):
			attributes = failed_child_workflow_events[0]['childWorkflowExecutionFailedEventAttributes']
			return "failed child workflow %s - %s (%s)" % (
				attributes['workflowExecution']['workflowId'],
				attributes['reason'],
				attributes['workflowType']['name'])
		failed_workflow_events = filter(lambda event: event['eventType'] == 'WorkflowExecutionFailed', history['events'])
		if len(failed_workflow_events):
			return "workflow failed %s" % failed_workflow_events[0]['workflowExecutionFailedEventAttributes']['reason']
			
		return str(history)

	def get_stack_trace_details(self, details):
		exception = json.loads(details)
		return self.get_exception_details(exception, None)

	def get_exception_details(self, exception, previous_message):
		exception_class = exception[0].split('.')[-1]
		if exception[1]['cause']:
			previous_message = self.get_sesame_calls(exception[1]['stackTrace'], None, exception_class, None)
			return self.get_exception_details(exception[1]['cause'], previous_message)
		else:
			return self.get_sesame_calls(exception[1]['stackTrace'], exception[1]['message'], exception_class, previous_message)

	def get_sesame_calls(self, stack_trace, message, exception_class, previous_message):
		sesame_calls = filter(lambda call: call['className'].find('sesame') != -1, stack_trace)
		if len(sesame_calls):
			class_name = sesame_calls[0]['className'].split('.')[-1]
			if message:
				new_message = "%s.%s (%s: %s)" % (class_name, sesame_calls[0]['methodName'], exception_class, message)
			else:
				new_message = "%s.%s (%s)" % (class_name, sesame_calls[0]['methodName'], exception_class)
			if previous_message:
				return "%s > %s" % (previous_message, new_message)
			else:
				return new_message
		else:
			return "%s > %s" % (previous_message, exception_class)

	def timestamp_to_string(self, timestamp):
		epoch = datetime.utcfromtimestamp(0)
		epoch += timedelta(seconds = timestamp)
		return epoch.strftime('%Y-%m-%d %H:%M:%S UTC')

	def convert_to_timestamp(self, dt):
		epoch = datetime.utcfromtimestamp(0)
		delta = dt - epoch
		return (delta.seconds + delta.days * 24 * 3600)

	def insert_result(self, line, edit, result):
		line_region = self.view.line(self.view.text_point(line, 0))
		line_text = self.view.substr(line_region)
		line_text = CallAwsApiCommand.CLEAR_RESULT_RE.sub('', line_text)
		line_text += ' -> ' + str(result)
		self.view.replace(edit, line_region, line_text)

	def find_access_keys(self):
		access_key = None
		secret_access_key = None
		access_key_line = self.view.find('!aws:access_key_id', 0)
		secret_access_key = self.view.find('!aws:secret_access_key', 0)
		if access_key_line != None:
			found = self.get_setting_value(access_key_line)
			if found != None:
				access_key = found[1]
		if secret_access_key != None:
			found = self.get_setting_value(secret_access_key)
			if found != None:
				secret_access_key = found[1]
		if access_key != None and secret_access_key != None:
			return (access_key, secret_access_key)
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
		matched = CallAwsApiCommand.COMMAND_RE.search(line_text)
		if matched:
			params = matched.group('params')
			if params == None:
				params = []
			else:
				params = CallAwsApiCommand.CLEAR_RESULT_RE.sub('', params)
				if len(params.strip()):
					params = [ p.strip() for p in re.split(',|\s+', params) ]
			return (matched.group('service'), matched.group('command'), params)
		else:
			return None

	def get_setting_value(self, region):
		line = self.view.substr(self.view.line(region))
		matched = CallAwsApiCommand.SETTING_RE.search(line)
		if matched:
			return (matched.group('key'), matched.group('value'))
		else:
			return None

	def report_error(self, message):
		print message

	def report_info(self, message):
		print message

	CLEAR_RESULT_RE = re.compile('\s?->.*')	
	SETTING_RE = re.compile('^\s*!\s*aws\s*:\s*(?P<key>[^:]+?)\s*=\s*(?P<value>\S+)')	
	COMMAND_RE = re.compile('^\s*!\s*(?P<service>[^:]+?)\s*:\s*(?P<command>[^(\s]+?)\\b(?:[\s|\(](?P<params>[^)]*)\)?)?')

