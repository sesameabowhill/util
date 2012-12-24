import xml.etree.ElementTree as ET
import urllib2
import base64
import re
import urllib

class UploadApiCall:
	def __init__(self, report):
		self.report = report
		
		access = self.report.find_access_keys('!internal:username', '!internal:password')
		if access != None:
			self.access = access
			self.report.report_info("using username %s" % self.access[0])

		else:
			self.report.report_error("can't find value for internal access (!internal:username=..., !internal:password=...)")

	def get_result(self, command):
		basic_password_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
		basic_password_mgr.add_password(None, "https://members.sesamecommunications.com", self.access[0], self.access[1])
		basic_password_mgr.add_password(None, "https://sync-logs.sesamecommunications.com", self.access[0], self.access[1])
		basic_password_mgr.add_password(None, "https://admin.sesamecommunications.com", self.access[0], self.access[1])
		basic_auth_handler = urllib2.HTTPBasicAuthHandler(basic_password_mgr)

		digest_password_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
		digest_password_mgr.add_password(None, "https://internal.sesamecommunications.com:8443", self.access[0], self.access[1])
		digest_auth_handler = urllib2.HTTPDigestAuthHandler(digest_password_mgr)
		
		opener = urllib2.build_opener(basic_auth_handler, digest_auth_handler)
		urllib2.install_opener(opener)   

		if command[0] == 'upload':
			if command[1] == 'status':
				return self.get_upload_status(command[2][0])
			else:
				self.report.report_error("unexpected command [%s] in [%s] group" % (command[1], command[0]))
		if command[0] == 'client':
			if command[1] == 'id':
				return self.get_client_id(command[2][0])
			else:
				self.report.report_error("unexpected command [%s] in [%s] group" % (command[1], command[0]))
		else:
			self.report.report_error("unexpected group [%s]" % command[0])
		return None

	def get_client_id(self, username):
		apis = self.get_apis(username)
		return "5.0 - %s, 24/7 - %s" % (apis[0].get_client_id(), apis[1].get_client_id())

	def get_upload_status(self, username):
		apis = self.get_apis(username)
		return "5.0 - %s, 24/7 - %s" % (apis[0].get_upload_status(), apis[1].get_upload_status())

	def get_apis(self, username):
		sesame_5_api = SesameApi(self.report, 'sesame 5: ', username, UploadApiCall.SESAME_5_FCS, UploadApiCall.SESAME_5_UPLOAD_LOGS)
		sesame_6_api = SesameApi(self.report, 'sesame 6: ', username, UploadApiCall.SESAME_6_FCS, UploadApiCall.SESAME_6_UPLOAD_LOGS)
		return (sesame_5_api, sesame_6_api)		


	SESAME_5_UPLOAD_LOGS = 'https://internal.sesamecommunications.com:8443/UploadLogs/memberUploads.html?clientId=%s'
	SESAME_5_FCS = 'https://members.sesamecommunications.com/support-tools/sesame/fast_client_search/xml.cgi'

	SESAME_6_UPLOAD_LOGS = 'https://sync-logs.sesamecommunications.com/UploadLogs/memberUploads.html?clientId=%s'
	SESAME_6_FCS = 'https://admin.sesamecommunications.com/support-tools/sesame/fast_client_search/xml.cgi'


class SesameApi:
	def __init__(self, report, prefix, username, fcs_url, upload_logs_url):
		self.report = report
		self.prefix = prefix
		self.username = username
		self.fcs_url = fcs_url
		self.upload_logs_url = upload_logs_url

	def get_upload_status(self):
		client_id = self.get_client_id()
		if client_id:
			self.report_info("client id: " + client_id)
			response = self.get_page_request_result(self.upload_logs_url % client_id)
			image_found = SesameApi.EXTRACTOR_HEALTH_RE.search(response)
			if image_found:
				filling_statuses = self.get_sql_result('upload_filling_status', 'last, status, error_message', 'client_id='+client_id)
				if len(filling_statuses):
					status = filling_statuses[0]
					return "health: %s (%s, last %s)" % (image_found.group('status'), status['status'], status['last'])
				else:
					return "health: %s" % image_found.group('status')
			else:
				self.report_error("can't find health image")
				#print response[0:10000]
		else:
			self.report_error("can't find client id for " + self.username)
		return None

	def get_client_id(self):
		response = self.get_page_request_result(self.fcs_url, 
			{'action' : 'general_info', 'search_param' : self.username})
		xml = ET.fromstring(response)
		id_nodes = xml.findall('cl_id')
		if len(id_nodes):
			return id_nodes[0].text
		return None

	def get_sql_result(self, table, fields, condition):
		response = self.get_page_request_result(self.fcs_url, 
			{'action' : 'table_data', 'client' : self.username, 'condition' : condition, 'table' : table, 'fields' : fields})
		xml = ET.fromstring(response)
		lines = []
		for record in xml.findall('record'):
			row = {}
			for column in record.findall('*'):
				if column.get('null', None):
					row[column.tag] = None
				else:
					if column.text == None:
						row[column.tag] = ""
					else:
						row[column.tag] = column.text
			lines.append(row)
		#print lines
		return lines

	def get_page_request_result(self, url, params = None):
		request = urllib2.Request(url)
		if params:
			request.add_data(urllib.urlencode(params))
		response = urllib2.urlopen(request)
		return response.read()

	def report_info(self, message):
		self.report.report_info(self.prefix + message)

	def report_error(self, message):
		self.report.report_error(self.prefix + message)

	EXTRACTOR_HEALTH_RE = re.compile('<img\s+class="healthImage"\s+src="[^"]+/(?P<status>active|inactive).png')

