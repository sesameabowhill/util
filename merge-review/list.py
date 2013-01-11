#!/usr/bin/env python

import git, os, re, jira.client, hashlib
from datetime import datetime, timedelta
from string import replace, lower
import optparse



## Install
## easy_install GitPython
## easy_install jira-python
## https://bitbucket.org/ve6yeq/jira-python/raw/1a46dcaa062a4ca6c0257b6396d5f4438b93cd36/jira/client.py

## TODO 
## - dates
## - highlight issues
## - tags
## - github links: history, diff
## not merged tickets
## not fixed issues in version

class LogEntry:
	def __init__(self, string):
		attrs = string.split('\x01')
		self.commit = attrs[0]
		self.name = attrs[1]
		self.email = attrs[2]
		self.time = attrs[3]
		self.message = attrs[4]
		self.issue = None
		self.id = None

	def __str__(self):
		return "%s: %s" % (self.commit, self.name)

	def find_issue(self, jira_reader):
		issue_matched = LogEntry.ISSUE_RE.search(self.message)
		if issue_matched:
			issue = issue_matched.group('issue')
			self.issue = jira_reader.issue(issue)

	ISSUE_RE = re.compile('\\b(?P<issue>[A-Z]+-\d+)\\b')

class TagEntry:
	def __init__(self, tag):
		self.tag = tag
		

class JiraIssue:
	def __init__(self, issue):
		self.issue = issue.key
		self.versions = [ (v.name, v.id) for v in issue.fields.fixVersions ]
		self.priority = issue.fields.priority.name
		self.resolution = issue.fields.resolution.name if issue.fields.resolution else None
		self.status = issue.fields.status.name
		self.summary = issue.fields.summary
		user = issue.fields.assignee
		self.assignee = (user.name, user.displayName, user.emailAddress)

		short_priority = {
			'Priority 1' : 'P1',
			'Priority 2' : 'P2',
			'Priority 3' : 'P3',
			'Priority 4' : 'P4',
		}
		if self.priority in short_priority:
			self.priority = short_priority[self.priority]
		# print dir(self.assignee)
		# print self.assignee
		# print str(self)
		# quit()

	def __str__(self):
		return "%s: %s - %s (%s, %s, %s, %s)" % (self.issue, self.priority, self.summary, self.versions, self.resolution, self.status, self.assignee)

	def get_resolution(self):
		if self.resolution == 'Fixed/Complete' and self.status == 'Resolved':
			return 'Resolved'
		if self.status == 'Closed':
			return 'Closed'
		if self.resolution == None:
			return self.status
		return "%s (%s)" % (self.status, self.resolution)


class GitReader:
	def __init__(self, path):
		self.repo = git.Repo(path)
		self.git = git.Git(path)

	def list_branches(self):
		#self.update_origin()
		branches = self.get_branches()
		# print ','.join([b.name for b in self.repo.branches])
		# print dir(self.repo.branches[0])
		return branches

	def update_origin(self):
		origin = self.repo.remotes.origin
		print "update origin"
		origin.update()

	def get_tags(self):
		return [ (t.name, t.commit.hexsha) for t in self.repo.tags ]

	def get_branches(self):
		remote_branches = [ r for r in self.repo.remotes.origin.refs if re.search("^origin/(?:master|release)", r.name) ]
		# local_branchs = ( b.name for b in self.repo.branches )
		print "found branches: %s" % ', '.join(b.name for b in remote_branches)
		oldest_commit = (datetime.utcnow() - timedelta(days = 30*1)).strftime('%Y-%m-%d %H:%M:%S')

		branches = {}
		# same_commits = {}
		for branch in remote_branches:
			branch_name = branch.name.split('/')[1]
			print "log [%s]" % branch
			log_entries = self.get_log_entires(branch.name, oldest_commit)
			branches[branch_name] = log_entries[0:100]
			for key, commit in self.unique_commits_by_message(log_entries):
				commit.id = hashlib.md5('\n\n'.join(key)).hexdigest()

				# if not key in same_commits:
				# 	same_commits[key] = []
				# same_commits[key].append(commit)
		return branches

	def unique_commits_by_message(self, commits):
		commits_by_message = {}
		for commit in commits:
			commit_message = commit.message

			## striping list of conflicted files and replace it with list of actual files
			commit_message = GitReader.CONFLICT_RE.sub('', commit_message).strip()
			files = self.git.show(commit.commit, pretty = 'format:', name_only = True)
			commit_message += "\n\n" + files.strip()

			if not commit_message in commits_by_message:
				commits_by_message[commit_message] = []
			commits_by_message[commit_message].append(commit)

		for message_group, commits in commits_by_message.iteritems():
 			if len(commits) > 1:
 				commits_by_lines = {}
				for commit in commits:
					lines = self.git.show(commit.commit, pretty = 'format:')
					lines = '\n'.join(GitReader.DIFF_LINE_RE.findall(lines))
					#print lines
					if not lines in commits_by_lines:
						commits_by_lines[lines] = []
					commits_by_lines[lines].append(commit)
		 		for line_group, commits in commits_by_lines.iteritems():
		 			for commit in commits:
		 				yield ((message_group, line_group), commit)
			else:
				yield ((message_group), commits[0])

	def get_log_entires(self, source, since):
		log = self.git.log(source, pretty = 'format:%H%x01%an%x01%ae%x01%at%x01%s%n%b%x02', since = since, no_merges = True)
		return [ LogEntry(l.strip()) for l in log.split('\x02') if len(l) ]

	# def get_branch_log(self, branch):
	# 	print self.repo.branches
	# 	# print [ h.name for h in self.repo.heads ]

	def lines_to_list(self, string):
		return [ s.strip() for s in string.split('\n') ]

	DIFF_LINE_RE = re.compile('^[+-].*', re.MULTILINE)
	CONFLICT_RE = re.compile('^Conflicts:.*', re.MULTILINE | re.DOTALL)

class JiraReader:
	def __init__(self, server, username, password):
		self.jira = jira.client.JIRA(basic_auth = (username, password), options = {'server' : server})
		self.known_issues = {}

	def issue(self, issue_number):
		if not issue_number in self.known_issues:
			try:
				self.known_issues[issue_number] = JiraIssue(self.jira.issue(issue_number))
				print "found issue [%s]" % issue_number
			except jira.exceptions.JIRAError, error:
				if error.status_code == 404:
					return None
				else:
					raise error
		return self.known_issues[issue_number]

class ReportBuild:
	def __init__(self, path, output, jira_user, jira_password):
		self.path = path
		self.output = output
		self.jira_user = jira_user
		self.jira_password = jira_password

		self.jira_url = 'https://jira.sesamecommunications.com:8443/'
		self.github_url = 'https://github.com/sesacom/web/'

	def build(self):
		git_reader = GitReader(self.path)
		git_reader.update_origin()
		branches = git_reader.list_branches()
		jira_reader = JiraReader(self.jira_url, self.jira_user, self.jira_password)
		for logs in branches.values():
			for log in logs:
				log.find_issue(jira_reader)
		tags = git_reader.get_tags()
		new_branches = {}
		for branch, logs in branches.iteritems():
			logs = self.insert_tags(logs, tags)
			logs = self.remove_jenkins(logs)
			new_branches[branch] = logs
		branches = self.group_by_issue(new_branches)
		report = self.make_report(branches)
		self.write_report(report)

	def group_by_issue(self, all_branches):
		by_issue = {}
		for branch, logs in all_branches.iteritems():
			for log in logs:
				if isinstance(log, LogEntry) and log.issue:
					issue_key = log.issue.issue
					if not issue_key in by_issue:
						by_issue[issue_key] = {}
					if not branch in by_issue[issue_key]:
						by_issue[issue_key][branch] = []
					by_issue[issue_key][branch].append(log)

		id_group = {}
		for issue_key, branches in by_issue.iteritems():
			id_intersect = frozenset(log.id for log in branches[branches.keys()[0]])
			for branch, logs in branches.iteritems():
				id_intersect = id_intersect.intersection(frozenset(log.id for log in logs))

			group_id = hashlib.md5('\n'.join(id_intersect)).hexdigest()
			for branch, logs in branches.iteritems():
				for log in logs:
					if log.id in id_intersect:
						id_group[log.commit] = group_id
					else:
						id_group[log.commit] = log.id

		new_branches = {}
		for branch, logs in all_branches.iteritems():
			logs_by_group = {}
			new_logs = []
			for log in logs:
				if isinstance(log, LogEntry):
					if log.issue:
						group = id_group[log.commit]
						if not group in logs_by_group:
							logs_by_group[group] = []
							new_logs.append((group, log.issue, logs_by_group[group]))
						logs_by_group[group].append(log)
					else:
						new_logs.append((log.id, None, [log]))
				else:
					new_logs.append(log)
			new_branches[branch] = new_logs
		return new_branches

	def insert_tags(self, logs, tags):
		tag_by_commit = {}
		for tag in tags:
			tag_by_commit[tag[1]] = tag[0]
		new_logs = []
		for log in logs:
			if log.commit in tag_by_commit:
				new_logs.append(TagEntry(tag_by_commit[log.commit]))
			new_logs.append(log)
		return new_logs

	def remove_jenkins(self, logs):
		return [ log for log in logs if not isinstance(log, LogEntry) or log.email != 'jenkins@sesamecommunications.com' ]

	def write_report(self, report):
		f = open(self.output, 'w')
		for line in report:
			f.write(line + "\n")
		f.close()

	def make_report(self, branches):
		lines = []
		lines.append("""
<html>
	<head>
	<title>Merge Review</title>
	<style>
		body { font-family: Arial, Verdana, Helvetica}
		table {border-collapse: collapse; border: 1px #000 solid; width: 100%}
		td, th {border-bottom:  1px #000 solid; padding: 0.3em 0.5em; border-left: 1px #000 dashed}
		th {color: #999; font-weight: normal;}
		h2 {font-size: 14pt}
		.number {text-align: right;}
		th a {color: #000;}
		.sort {background-color: #eee;}
		.in_progress {background-color: #FFFFBC;}
		.complete {background-color: #C3FFBC;}
		.column {float: left}
		.column-content {margin-left: 0.5em}
		.versions {font-size: 10pt; color: #aaa}
		.author {font-size: 10pt; color: #aaa}
		.version-highlight {color: #000}
		.commit-warn {background-color: #fdd2ad !important}
		.commit-highlight {background-color: #fff2c7}
		.commit-select {background-color: #ceffc7}
		.commit-select.commit-highlight {background-color: #e3ffac}
		.tag {font-weight: bold; padding: 0.5em 0.5em}
		.commit {font-size: 10pt; color: #aaa}
		.commit {max-width: 5em}
		.github-link, .github-link a {color: #888}
		.github-link a:hover, .github-link:hover {color: #555}
		h2 .github-link, .tag .github-link  {font-size: 10pt}
		.status-closed {text-decoration: line-through}
		.status-open, .status-reopened {font-style: italic}
		.unknown-resolution {color: #000}
		.issue-summary, .version-name, .name-author {white-space: nowrap;}
		.no-data {text-align: center; width: 100%; display: block}
		.missing-versions {font-size: 10pt}
		.show-links .github-link {display: none}
	</style>
	<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8.3/jquery.min.js"></script>
	<script>
		$(function() {
			var with_hightlight = function(elem_selector, prefix, callback) {
				elem_selector.each(function (index, elem) {
					var class_list = $(elem).attr('class').split(/\s+/);
					$.each(class_list, function(index, class_name) {
					    if (class_name.indexOf(prefix) === 0) {
					    	callback(class_name);
					    }
					});
				});
			};
			$(".highlight-commit").bind({
				click: function() {
					with_hightlight($(this), "group-", function (class_name) {
						$("." + class_name).parents("tr").toggleClass("commit-select");
					});
				},
				mouseenter: function() {
					with_hightlight($(this), "group-", function (class_name) {
						$("." + class_name).parents("tr").addClass("commit-highlight");
					});
				},
				mouseleave: function() {
					with_hightlight($(this), "group-", function (class_name) {
						$("." + class_name).parents("tr").removeClass("commit-highlight");
					});
				}
			});
			$(".highlight-version").bind({
				click: function(e) {
					if (e.shiftKey) {
						e.preventDefault();
					}
					with_hightlight($(this), "group-", function (class_name) {
						var elems = $("." + class_name).parents("tr");
						elems.toggleClass("commit-select");
					});
				},
				mouseenter: function() {
					with_hightlight($(this), "group-", function (class_name) {
						$("." + class_name).addClass("version-highlight");
						$("." + class_name).parents("tr").addClass("commit-highlight");
					});
				},
				mouseleave: function() {
					with_hightlight($(this), "group-", function (class_name) {
						$("." + class_name).removeClass("version-highlight");
						$("." + class_name).parents("tr").removeClass("commit-highlight");
					});
				}
			});
			$(".highlight-branch").bind({
				click: function(e) {
					if (e.shiftKey) {
						$(".commit-select").removeClass("commit-select");
					}
					with_hightlight($(this), "branch-", function (branch_class_name) {
						var selected = {};
						with_hightlight($("." + branch_class_name), "group-", function (class_name) {
							if (!selected[class_name]) {
								selected[class_name] = 1;
								$("." + class_name).parents("tr").toggleClass("commit-select");
							}
						});
					});
				},
				mouseenter: function() {
					with_hightlight($(this), "branch-", function (branch_class_name) {
						with_hightlight($("." + branch_class_name), "group-", function (class_name) {
							$("." + class_name).parents("tr").addClass("commit-highlight");
						});
					});
				},
				mouseleave: function() {
					with_hightlight($(this), "branch-", function (branch_class_name) {
						with_hightlight($("." + branch_class_name), "group-", function (class_name) {
							$("." + class_name).parents("tr").removeClass("commit-highlight");
						});
					});
				}
			});
			$(".highlight-author").bind({
				click: function(e) {
					e.stopPropagation();
					if (e.shiftKey) {
						$(".commit-select").removeClass("commit-select");
					}
					with_hightlight($(this), "author-", function (author_class_name) {
						var selected = {};
						with_hightlight($("." + author_class_name).parents("td"), "group-", function (class_name) {
							if (!selected[class_name]) {
								selected[class_name] = 1;
								$("." + class_name).parents("tr").toggleClass("commit-select");
							}
						});
					});
				},
				mouseenter: function(e) {
					e.stopPropagation();
					var elem = $(this);
					with_hightlight(elem.parents("td"), "group-", function (selected_class_name) {
						with_hightlight(elem, "author-", function (author_class_name) {
							var elems = $("." + author_class_name);
							elems.addClass("version-highlight");
							with_hightlight(elems.parents("td"), "group-", function (class_name) {
								if (selected_class_name !== class_name) {
									$("." + class_name).parents("tr").addClass("commit-highlight");
								}
							});
						});
					});
				},
				mouseleave: function(e) {
					e.stopPropagation();
					var elem = $(this);
					with_hightlight(elem.parents("td"), "group-", function (selected_class_name) {
						with_hightlight(elem, "author-", function (author_class_name) {
							var elems = $("." + author_class_name);
							elems.removeClass("version-highlight");
							with_hightlight(elems.parents("td"), "group-", function (class_name) {
								if (selected_class_name !== class_name) {
									$("." + class_name).parents("tr").removeClass("commit-highlight");
								}
							});
						});
					});
				}
			});
			$(".highlight-issue").bind({
				click: function(e) {
					e.stopPropagation();
					with_hightlight($(this), "issue-", function (issue_class_name) {
						var selected = {};
						with_hightlight($("." + issue_class_name).parent(), "group-", function (class_name) {
							if (!selected[class_name]) {
								selected[class_name] = 1;
								$("." + class_name).parents("tr").toggleClass("commit-select");
							}
						});
					});
				},
				mouseenter: function(e) {
					var elem = $(this);
					with_hightlight(elem.parent(), "group-", function (selected_class_name) {
						with_hightlight(elem, "issue-", function (issue_class_name) {
							with_hightlight($("." + issue_class_name).parent(), "group-", function (class_name) {
								if (class_name !== selected_class_name) {
									$("." + class_name).parents("tr").addClass("commit-warn");
								}
							});
						});
					});
				},
				mouseleave: function(e) {
					with_hightlight($(this), "issue-", function (issue_class_name) {
						with_hightlight($("." + issue_class_name).parent(), "group-", function (class_name) {
							$("." + class_name).parents("tr").removeClass("commit-warn");
						});
					});
				}
			});
			$(".show-links").bind({
				mouseenter: function(e) {
					$(this).children(".github-link").fadeIn("fast");
				},
				mouseleave: function(e) {
					$(this).children(".github-link").fadeOut("fast");
				}
			});
		});
		
	</script>
	</head>
<body>
""")
		for name, log in branches.iteritems():
			lines.append("<div class='column' style='width: %d%%'>" % int(100 / len(branches)))
			lines.append("<div class='column-content'>")
			lines += self.make_table(name, log)
			lines.append("</div>")
			lines.append("</div>")
		lines.append("</body>")
		lines.append("</html>")
		return lines

	def make_missing_issues_links(self, name, logs):
		issues_by_version = {}
		for log in logs:
			if type(log) is tuple:
				log_issue = log[1]
				if log_issue:
					for version in log_issue.versions:
						if not version in issues_by_version:
							issues_by_version[version] = []
						issues_by_version[version].append(log_issue)
		links = []
		for version in sorted(issues_by_version):
			issues = issues_by_version[version]
			jira_project = issues[0].issue.split('-')[0]
			query = "project=%s AND fixVersion=%s AND NOT (%s)" % (jira_project, version[1], 
				' OR '.join("key=%s" % issue.issue for issue in issues))
			links.append("<a href='%ssecure/IssueNavigator.jspa?reset=true&jqlQuery=%s' class='highlight-version version-name group-version-%s' title='issues from [%s] non merged into %s'>%s</a>" % 
				(self.jira_url, self.escape_attr(query), self.escape_attr(version[1]), self.escape_attr(version[0]), 
					self.escape_attr(name), self.escape_attr(version[0])))
		return [ "<span class='github-link missing-versions'>%s</span>" %  ', '.join(links) ]

	def make_table(self, name, logs):
		lines = []
		name_class = replace(name, '.', '-')
		lines.append("<h2 title='shift-click to select only this branch' class='highlight-branch branch-%s show-links'>%s" % (name_class, name))
		lines.append("<span class='github-link'>(<a href='%s' title='view on github'>log</a>)</span>" % (self.github_url + 'tree/' + name))
		lines.append("</h2>")
		lines += self.make_missing_issues_links(name, logs)
		lines.append("<table>")
		lines.append("<tr><th>Issue</th><th>Versions</th><th>Commit</th></tr>")
		diff_link = {}
		last_tag = None
		for log in reversed(logs):
			if isinstance(log, TagEntry):
				if last_tag:
					diff_link[log.tag] =(", <a href='%scompare/%s...%s' title='diff with %s'>diff</a>" % 
						(self.github_url, last_tag, log.tag, last_tag))
				last_tag = log.tag

		current_tag = None
		for log in logs:
			if isinstance(log, TagEntry):
				current_tag = replace(log.tag, '.', '-')
				lines.append("<tr><td colspan='3' class='tag show-links'>")
				lines.append("<span title='shift-click to select only this tag' class='highlight-branch branch-%s'>%s</span>" % (current_tag, log.tag))
				lines.append("<span class='github-link'>(<a href='%s' title='view on github'>log</a>%s)</span>" % 
					(self.github_url + 'tree/' + log.tag, (diff_link[log.tag] if log.tag in diff_link else "")))
				lines.append("</td></tr>")
			else:
				lines += self.make_log_row(name_class, current_tag, log)
		lines.append("</table>")
		return lines

	def make_log_row(self, name_class, current_tag, log):
		lines = []
		log_id = log[0]
		log_issue = log[1]
		logs = log[2]
		lines.append("<tr>")
		group_highlight = "highlight-commit group-commit-id-%s branch-%s branch-%s" % (log_id, name_class, current_tag)
		issue_title = self.escape_attr(log_issue.summary) if log_issue else logs[0].message
		lines.append("<td class='%s' title='%s'>" % (group_highlight, issue_title))
		if log_issue:
			lines.append("<span class='highlight-issue issue-%s'>" % self.escape_class(log_issue.issue))
			lines.append("<a href='%s' class='status-%s'>%s</a>" % (self.jira_url + 'browse/' + log_issue.issue, 
				self.escape_class(log_issue.get_resolution()), self.escape(log_issue.issue)))
			lines.append(" <span class='issue-summary'>%s</span><br/>" % self.short(log_issue.summary, 20))
			lines.append("</span>")
			resolution_class = 'author' if log_issue.get_resolution() in ('Resolved', 'Closed') else 'unknown-resolution'
			lines.append("<span class='author'>(<span class='%s'>%s</span>, assignee: %s)</span>" % 
				(resolution_class, self.escape(log_issue.get_resolution()), self.escape(log_issue.assignee[1])))
		else:
			lines.append("<span class='issue-summary' title='%s'>%s</span>" % 
				(self.escape_attr(logs[0].message), self.short(logs[0].message, 30)))
		authors = {}
		for log in logs:
			authors[log.name] = 1
		authors = sorted(authors.keys())
		lines.append("<div class='author'>Author%s: %s</div>" % 
			('' if len(authors) == 1 else 's', ', '.join("<span class='name-author highlight-author author-%s'>%s</span>" % 
				(self.escape_class(name), self.escape(name)) for name in authors)))
		lines.append("</td>")
		lines.append("<td class='versions'>")
		if log_issue:
			lines.append('<br/>'.join("<span title='%s' class='highlight-version version-name group-version-%s'>%s</span>" % 
				(self.escape_attr(v[0]), v[1], self.short(v[0], 15)) 
				for v in sorted(log_issue.versions)))
		else:
			lines.append("<span class='no-data'>&mdash;</span>")
		lines.append("</td>")
		lines.append("<td class='commit %s'>" % group_highlight)
		lines.append(', '.join("<a title='%s' class='github-link' href='%s'>%s</a>" % (self.escape_attr(log.name + " - " + log.message), 
			self.github_url + 'commit/' + log.commit, self.short_commit(log.commit)) for log in logs))
		lines.append("</td>")
		lines.append("</tr>")
		return lines

	def short_commit(self, string):
		return string[0:4]

	def to_line(self, string):
		return self.escape(re.sub('\s+', ' ', string))

	def short(self, string, length):
		if len(string) > length:
			return self.escape(string[0:length-3]) + "..."
		else:
			return self.escape(string)

	def escape(self, string):
		return replace(replace(string, '<', '&lt;'), '>', '&gt;')
	
	def escape_attr(self, string):
		return replace(replace(replace(self.escape(string), '\'', '`'), '\r', ''), '\n', ' ')

	def escape_class(self, string):
		string = re.sub('[^a-z0-9]', '-', lower(string))
		string = re.sub('-+', '-', string)
		return string



if __name__ == "__main__":
	#os.environ['GIT_PYTHON_TRACE'] = 'full'
	#report_build = ReportBuild('C:/Users/ivan/Projects/web8', 'C:/Users/ivan/Desktop/rep.html')
	#report_build = ReportBuild('/Users/ivan/web', '/Users/ivan/Desktop/rep.html')

	parser = optparse.OptionParser()
	parser.add_option("-g", "--git-folder", dest="git", help="Git folder to use")
	parser.add_option("-o", "--output", dest="output", help="File to write HTML to")
	parser.add_option("-u", "--jira-user", dest="jira_user", help="User for Jira api access")
	parser.add_option("-p", "--jira-password", dest="jira_password", help="Password for Jira api access")
	(options, args) = parser.parse_args()
	if not options.git or not options.output or not options.jira_user or not options.jira_password:
		parser.error("missing options")

	report_build = ReportBuild(options.git, options.output, options.jira_user, options.jira_password)
	report_build.build()
