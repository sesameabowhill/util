function SuggestLink() {
	 var commands = {
		"cp" : {
			"url": "https://members.sesamecommunications.com/%s/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/%s/",
			"url_iet": "https://md-iet.sesamecom.com/",
			"title": "go to [<match>%s</match>] <match>Control Panel</match>",
			"title_stage": "go to [<match>%s</match>] <match>Stage Control Panel</match>",
			"title_iet": "go to [<match>%s</match>] <match>IET Control Panel</match>",
			"need_client": true,
			"suffix": true,
			"clients_stage": {}
		}, 
		"pp" : {
			"url": "https://login.sesamecommunications.com/%s/index.html",
			"url_stage": "https://pp-stage1-1.sesamecommunications.com/%s/index.html",
			"url_iet": "https://pp-iet.sesamecom.com/%s/index.html",
			"title": "go to [<match>%s</match>] <match>Patient Pages</match>" ,
			"title_stage": "go to [<match>%s</match>] <match>Stage Patient Pages</match>" ,
			"title_iet": "go to [<match>%s</match>] <match>IET Patient Pages</match>" ,
			"need_client": true,
			"suffix": true,
			"clients_stage": {}
		}, 
		"staff" : {
			"url": "https://members.sesamecommunications.com/%s/staff.cgi",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/%s/staff.cgi",
			"title": "go to [<match>%s</match>] <match>Staff Access</match> (Patient Pages)" ,
			"title_stage": "go to [<match>%s</match>] <match>Stage Staff Access</match> (Patient Pages)" ,
			"need_client": true,
			"suffix": true,
			"clients_stage": {}
		}, 
		"internal" : {
			"url": "https://internal.sesamecommunications.com:8443/internal/member-information.html",
			"url_stage": "http://ip-stage1-1.sesamecommunications.com:8080/internal/member-information.html",
			"url_iet": "https://ip-iet.sesamecom.com/member-information.html",
			"suffix": true,
			"title": "go to <match>Internal</match>",
			"title_stage": "go to <match>Stage Internal</match>",
			"title_iet": "go to <match>IET Internal</match>"
		},
		"invisalign" : {
			"url": "https://members.sesamecommunications.com/support-tools/invisalign-processing/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/support-tools/invisalign-processing/",
			"url_iet": "https://ip-iet.sesamecom.com/support-tools/invisalign-processing/",
			"suffix": true,
			"title": "go to <match>Invisalign</match> tool",
			"title_stage": "go to <match>Stage Invisalign</match> tool",
			"title_iet": "go to <match>IET Invisalign</match> tool"
		},
		"jira" : {
			"url": "https://jira.sesamecommunications.com:8443/secure/QuickSearch.jspa?searchString=%s",
			"title": "Search for [<match>%s</match>] in <match>Jira</match>"
		}, 
		"confluence" : {
			"url": "http://wiki.sesamecommunications.com:8090/dosearchsite.action?queryString=%s",
			"title": "Search for [<match>%s</match>] in <match>Confluence</match>"
		}, 
		"demo" : {
			"url": "http://demo-stage.sesamecommunications.com/sesame_demo/login.cgi?user=%s",
			"title": "go to <match>Demo</match> [<match>%s</match>]",
			"clients": {
				"1": "dental_demo_1",
				"2": "ortho_demo_2",
				"dental_demo_1": "dental_demo_1", 
				"ortho_demo_2": "ortho_demo_2"
			},
			"need_client": true
		},
		"upload_logs" : {
			"url": "https://internal.sesamecommunications.com:8443/UploadLogs/index.html",
			"url_stage": "https://ip-stage1-1.sesamecommunications.com:8443/UploadLogs/index.html",
			"suffix": true,
			"title": "go to <match>Upload Logs</match>",
			"title_stage": "go to <match>Stage Upload Logs</match>"
		},
		"ppn" : {
			"url": "https://members.sesamecommunications.com/support-tools/ppn-console/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/support-tools/ppn-console/",
			"suffix": true,
			"title": "go to <match>PPN Console</match> (Newsletters)",
			"title_stage": "go to <match>Stage PPN Console</match> (Newsletters)"
		},
		"si_logs" : {
			"url": "https://internal.sesamecommunications.com:8443/si-monitoring/",
			"url_stage": "https://ip-stage1-1.sesamecommunications.com:8443/si-monitoring/",
			"suffix": true,
			"title": "go to <match>SI Logs</match>",
			"title_stage": "go to <match>Stage SI Logs</match>"
		},
		"new_client" : {
			"url": "https://members.sesamecommunications.com/install/member/default.htm",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/install/member/default.htm",
			"suffix": true,
			"title": "go to <match>New Client Installer</match>",
			"title_stage": "go to <match>Stage New Client Installer</match>"
		},
		"voice" : {
			"url": "https://members.sesamecommunications.com/install/voice/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/install/voice/",
			"suffix": true,
			"title": "go to <match>Voice Installer</match>",
			"title_stage": "go to <match>Stage Voice Installer</match>"
		},
		"opse" : {
			"url": "https://members.sesamecommunications.com/install/opse/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/install/opse/",
			"suffix": true,
			"title": "go to <match>Credit Card Payment Installer</match>",
			"title_stage": "go to <match>Stage Credit Card Payment Installer</match>"
		},
		"hhf" : {
			"url": "https://members.sesamecommunications.com/install/hhf/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/install/hhf/",
			"suffix": true,
			"title": "go to <match>HHF Installer</match> (Patient Forms)",
			"title_stage": "go to <match>Stage HHF Installer</match> (Patient Forms)"
		},
		"sms" : {
			"url": "https://members.sesamecommunications.com/install/sms/",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/install/sms/",
			"suffix": true,
			"title": "go to <match>SMS Installer</match>",
			"title_stage": "go to <match>Stage SMS Installer</match>"
		},
		"fcs" : {
			"url": "https://members.sesamecommunications.com/support-tools/sesame/fast_client_search/?search_param=%s",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/support-tools/sesame/fast_client_search/?search_param=%s",
			"url_iet": "https://ip-iet.sesamecom.com/support-tools/sesame/fast_client_search/?search_param=%s",
			"suffix": true,
			"title": "Search for [<match>%s</match>] <match>client</match>",
			"title_stage": "Search <match>Stage</match> for [%s] <match>client</match>",
			"title_iet": "Search <match>IET</match> for [%s] <match>client</match>"
		}, 
		"visitor" : {
			"url": "https://members.sesamecommunications.com/support-tools/sesame/fast_client_search/?find=visitor&search_param=%s",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/support-tools/sesame/fast_client_search/?find=visitor&search_param=%s",
			"url_iet": "https://ip-iet.sesamecom.com/support-tools/sesame/fast_client_search/?find=visitor&search_param=%s",
			"suffix": true,
			"title": "Search for [<match>%s</match>] <match>visitor</match>",
			"title_stage": "Search <match>Stage</match> for [<match>%s</match>] <match>visitor</match>",
			"title_iet": "Search <match>IET</match> for [<match>%s</match>] <match>visitor</match>"
		}, 
		"slm" : {
			"url": "https://members.sesamecommunications.com/support-tools/error_reporter/?search=%s",
			"url_stage": "https://cp-stage1-1.sesamecommunications.com/support-tools/error_reporter/?search=%s",
			"url_iet": "https://ip-iet.sesamecom.com/support-tools/error_reporter/?search=%s",
			"suffix": true,
			"title": "Search for [<match>%s</match>] in <match>Errors</match>",
			"title_stage": "Search for [<match>%s</match>] in <match>Stage Errors</match>",
			"title_iet": "Search for [<match>%s</match>] in <match>IET Errors</match>"
		}
	};
	commands.error = commands.slm;
	commands.wiki = commands.confluence;
	commands.client = commands.fcs;
	commands.ccp = commands.opse;
	commands.payment = commands.opse;
	commands.patient = commands.visitor;
	commands.responsible = commands.visitor;
	this.commands = commands;
	
	this.command_finder = new CommandFinder(Object.keys(commands));
	this.suffix_finder = new CommandFinder([ "stage", "iet" ]);
}

SuggestLink.prototype.get_link_suggestions = function (str, client_names) {
	var found_commands = this._find_commands(str, client_names, false);
	var self = this;
	return found_commands.map(function (command) {
		var title = self._get_param("title", command);
		title = title.replace('%s', command.skipped.join(" "));
		var content = [ command.command ];
		if (command.params.suffix && command.suffix.length > 0) {
			content.push(command.suffix);
		}
		content = content.concat(command.skipped);
		return {
			"content" : content.join(" ") + " ",
			"description" : title
		};
	});
};

SuggestLink.prototype.get_url = function (str, client_names) {
	var found_commands = this._find_commands(str, client_names, true);
	if (found_commands.length == 1) {
		var url = this._get_param("url", found_commands[0]);
		url = url.replace('%s', found_commands[0].skipped.join(" ").replace(/\s+$/, ""));
		return url;
	}
	else {
		return null;
	}
};

SuggestLink.prototype._group_params = function (commands, need_one) {
	var grouped = [];
	var self = this;
	var clients = (commands.clients ? commands.clients : []);
	commands.found.forEach(function (command) {
		var cmd = {
			"command": command,
			"skipped": commands.skipped,
			"suffix": commands.suffix,
			"clients": commands.clients[command],
			"params": self.commands[command]
		};
		if (cmd.params.need_client) {
			if (cmd.clients.length == 1) {
				cmd.skipped = [ cmd.clients[0] ];
				grouped.push(cmd);
			}
			else {
				grouped.push(cmd);
				if (!need_one) {
					var clients = cmd.clients;
					if (clients.length > 5) {
						clients = clients.splice(0, 5);
					}
					clients.forEach(function (client) {
						var new_cmd = Object.create(cmd);
						new_cmd.skipped = [ client ];
						grouped.push(new_cmd);
					});
				}
			}
		}
		else {
			grouped.push(cmd);
		}
	});
	return grouped;
};

SuggestLink.prototype._get_param = function (name, command) {
	var key = name;
	if (command.params.suffix) {
		if (command.suffix.length > 0) {
			key += "_" + command.suffix;
			if (!(key in command.params)) {
				key = name;
			}
		}
	}
	return command.params[key];
};

SuggestLink.prototype._find_commands = function (str, client_names, need_one) {
	var words = str.split(/\s+/);
	var found_commands = this._find_first_command(words, this.command_finder);
	if (found_commands.found.length > 0) {
		if (this._any_command_have(found_commands.found, 'suffix')) {
			var found_suffix = this._find_first_command(found_commands.skipped, this.suffix_finder);
			if (found_suffix.found.length == 1) {
				found_commands.suffix = found_suffix.found[0];
				found_commands.skipped = found_suffix.skipped;
			}
		}
		var self = this;
		found_commands.found.forEach(function (command) {
			if (self.commands[command].need_client) {
				var clients_map = self._get_param(
					"clients", 
					{
						"params": self.commands[command], 
						"suffix": found_commands.suffix
					}
				) || client_names;
				var client_finder = new CommandFinder( Object.keys( clients_map ) );
				var names = client_finder.get_suggestions(found_commands.skipped.join(" "));
				found_commands.clients[command] = names.map(function (name) {
					return clients_map[name];
				});
			}
			else {
				found_commands.clients[command] = [];
			}
		});
	}
	return this._group_params(found_commands, need_one);
}

SuggestLink.prototype._any_command_have = function (commands, name) {
	var self = this;
	return commands.some(function (cmd) {
		return name in self.commands[cmd] && self.commands[cmd][name];
	});
};

SuggestLink.prototype._find_first_command = function (words, command_finder) {
	var non_command_words = [];
	var found_commands = [];
	words.forEach(function (word) {
		if (found_commands.length > 0) {
			non_command_words.push(word);
		}
		else {
			var suggestions = command_finder.get_suggestions(word);
			if (suggestions.length > 0) {
				found_commands = suggestions;
			}
			else {
				non_command_words.push(word);
			}
		}
	});
	return {
		"found": found_commands,
		"skipped": non_command_words,
		"suffix": "",
		"clients": {}
	}
};

