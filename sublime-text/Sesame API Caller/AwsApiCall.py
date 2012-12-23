import re, time, json
from datetime import datetime, timedelta
from DateUtils import convert_to_timestamp, timestamp_to_string

import boto

import boto.swf.layer1
import boto.dynamodb.layer2

class AwsApiCall:
	def __init__(self, report, access):
		self.report = report
		self.access = access
		self.report.report_info("using access key %s" % self.access[0])

	def get_result(self, command):
		if command[0] == 'swf':
			if command[1] == 'list_domains':
				return self.swf_list_domains()
			elif command[1] == 'list_failed_workflows':
				return self.swf_list_closed_workflow_executions(command[2][0], 'FAILED')
			elif command[1] == 'workflow_status':
				return self.swf_workflow_status(command[2][0], command[2][1])
			else:
				self.report.report_error("unexpected command [%s] in [%s] service" % (command[1], command[0]))
		else:
			self.report.report_error("unexpected service [%s]" % command[0])
		return None

	def swf_list_domains(self):
		swf = boto.connect_swf(*self.access)
		self.report.report_info("list domains")
		return ', '.join(info['name'] for info in swf.list_domains('REGISTERED')['domainInfos'])

	def swf_list_closed_workflow_executions(self, domain, status):
		swf = boto.connect_swf(*self.access)
		now = datetime.utcnow()
		day_before = now - timedelta(days = 1)
		self.report.report_info("list %s executions in [%s], from [%sZ], to [%sZ]" % 
			(status, domain, str(day_before), str(now)))
		executions = swf.list_closed_workflow_executions(domain, 
			start_latest_date = convert_to_timestamp(now), 
			start_oldest_date = convert_to_timestamp(day_before),
			close_status = status)
		return ', '.join('%s - %s' % (execution['execution']['workflowId'], timestamp_to_string(execution['closeTimestamp'])) 
			for execution in executions['executionInfos'])

	def swf_workflow_status(self, domain, workflow_id):
		swf = boto.connect_swf(*self.access)
		now = datetime.utcnow()
		oldest = now - timedelta(days = 365)
		self.report.report_info("get workflow [%s] status, from [%sZ], to [%sZ], domain %s" % 
			(workflow_id, str(oldest), str(now), domain))
		executions = swf.list_closed_workflow_executions(domain, 
			start_latest_date = convert_to_timestamp(now), 
			start_oldest_date = convert_to_timestamp(oldest),
			workflow_id = workflow_id)
		if len(executions['executionInfos']):
			execution = executions['executionInfos'][0]
			status = execution['closeStatus']
			if status == 'FAILED':
				return "%s - %s" % (status, self.get_failed_details(swf, domain, execution['execution']))
			else:
				return "%s - %s" % (status, timestamp_to_string(execution['closeTimestamp']))
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

