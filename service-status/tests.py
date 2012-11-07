#!/usr/bin/env python

from servicestatus import *
import unittest


class TestFindVersionProcessor(unittest.TestCase):
	def test_release_version_from_log(self):
		processor = FindVersionProcessor("file")
		processor.process(LogRecord("INFO   | jvm 1    | 2012/11/02 00:15:32 |" + 
			" 00:15:32.838 [WrapperSimpleAppMain:DB=] INFO  c.s.util.ArtifactInfoReporter - " +
			"artifact->buildInformation buildTag: jenkins-web-do-release-62, " + 
			"buildId: 2012-11-01_18-33-43, buildUrl: https://jenkins.sesamecom.com/job/web-do-release/62/, " +
			"gitBranch: release, gitCommit: 45c8ef110e113c24b01c4e5125d0ce9c94c51ff9, applicationName: " + 
			"patient-pages-1.2.92, applicationVersion: 1.2.92", "file", None, LogRecord.NONE))

		self.assertEqual(processor.version, ("1.2.92", "patient-pages"))

	def test_snapshot_version_from_log(self):
		processor = FindVersionProcessor("file")
		processor.process(LogRecord("ArtifactInfoReporter applicationName: " + 
			"md-test-20121019.222117-32", "file", None, LogRecord.NONE))

		self.assertEqual(processor.version, ("test-20121019.222117-32", "md"))

	def test_feature_snapshot_version_from_log(self):
		processor = FindVersionProcessor("file")
		processor.process(LogRecord("ArtifactInfoReporter applicationName: " + 
			"md-f-test-20121019.222117-32", "file", None, LogRecord.NONE))

		self.assertEqual(processor.version, ("f-test-20121019.222117-32", "md"))

	def test_cannot_parse_name(self):
		processor = FindVersionProcessor("file")
		processor.process(LogRecord("ArtifactInfoReporter applicationName: " + 
			"md-test-20121019.222117", "file", None, LogRecord.NONE))

		self.assertEqual(processor.version, ("md-test-20121019.222117", None))

	def test_jetty_version(self):
		processor = FindVersionProcessor("file")
		processor.process(LogRecord("INFO   | jvm 1    | 2012/10/19 23:38:22 | 23:38:22.741 " +
			"[WrapperSimpleAppMain:DB=] INFO  o.e.jetty.webapp.WebInfConfiguration - Extract " +
			"jar:file:/home/sites/artifacts/md-test-20121019.222117-32-jetty-console.war!/ to " +
			"/var/tmp/jetty-0.0.0.0-82-md-test-20121019.222117-32-jetty-console.war-_-any-/webapp", 
			"file", None, LogRecord.NONE))

		self.assertEqual(processor.version, ("test-20121019.222117-32", "md"))

	def test_use_artifact_version_first(self):
		processor = FindVersionProcessor("file")
		processor.process(LogRecord("ArtifactInfoReporter applicationName: " + 
			"md-test-20121019.222117-32", "file", None, LogRecord.NONE))
		processor.process(LogRecord("WebInfConfiguration - Extract " +
			"jar:file:/home/sites/artifacts/md-test-20121019.222117-33-jetty-console.war!/", 
			"file", None, LogRecord.NONE))

		self.assertEqual(processor.version, ("test-20121019.222117-32", "md"))

class TestFindPropertiesProcessor(unittest.TestCase):
	def test_env_property(self):
		processor = FindPropertiesProcessor("file")
		processor.process(LogRecord("INFO   | jvm 1    | 2012/10/19 23:38:55 | 23:38:55.163 " +
			"[WrapperSimpleAppMain:DB=] INFO  c.sesamecom.config.EnvironmentConfig - property->resolved " +
			"name: persistSchema, value: 'sesame_stage_db', source: SYSTEM, configFilePath: [none defined " +
			"via -DsesameConfigurationFile]", "file", None, LogRecord.NONE))

		self.assertEqual(processor.properties, {'persistSchema' : ("'sesame_stage_db'", 'SYSTEM')})

	def test_property_from_file(self):
		processor = FindPropertiesProcessor("file")
		processor.process(LogRecord("INFO   | jvm 1    | 2012/10/24 19:19:55 | 19:19:55.474 " +
			"[WrapperSimpleAppMain] INFO  c.sesamecom.config.EnvironmentConfig - property->resolved " +
			"name: janitorCleanupAlarmName, value: 'va-iet-web-01_cleanupAlarm', source: FILE, " +
			"configFilePath: /home/sesame.properties", "file", None, LogRecord.NONE))

		self.assertEqual(processor.properties, {'janitorCleanupAlarmName' : ("'va-iet-web-01_cleanupAlarm'", '/home/sesame.properties')})

	def test_default_property(self):
		processor = FindPropertiesProcessor("file")
		processor.process(LogRecord("INFO   | jvm 1    | 2012/10/24 19:18:00 | 19:18:00.324 " +
			"[WrapperSimpleAppMain] WARN  c.sesamecom.config.EnvironmentConfig - optionalProperty->defaultValueUsed " +
			"name: useBasicDataSource, defaultValue: false, configFilePath: " +
			"/home/sites/wrapper/conf/janitor/sesame.properties", "file", None, LogRecord.NONE))

		self.assertEqual(processor.properties, {'useBasicDataSource' : ("false", 'DEFAULT')})




if __name__ == '__main__':
    unittest.main()