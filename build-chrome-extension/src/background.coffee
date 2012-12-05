class Jobs
	constructor: (jobs) ->
		@jobs = jobs
		@is_success = /^blue$/
		@is_running = /_anime$/

	is_empty: ->
		return ! @jobs.length

	get_names: ->
		return ("<a href=\"#{job.url}/lastBuild/\" target=\"_blank\">#{job.name}</a>" for job in @jobs)

	get_succesful_jobs: ->
		return new Jobs(job for job in @jobs when @is_success.test(job.color))

	get_failed_jobs: ->
		return new Jobs(job for job in @jobs when ! @is_success.test(job.color))

	get_running_jobs: ->
		return new Jobs(job for job in @jobs when @is_running.test(job.color))


class JenkinsStatusChecker
	constructor: ->
		# calm, buildingComponents, buildingRelease
		@last_state = null
		@last_state_change = null

		@is_release = /^\+release-candidate$/
		@base_url = "https://jenkins.sesamecom.com/view/Web%20Release/"
		#@is_release = /-pp$/
		#@base_url = "https://ci.sesamecom.com/jenkins/view/Legacy/"
		@message_queue = []

		chrome.browserAction.setBadgeBackgroundColor color: [0, 174, 183, 255]
		chrome.browserAction.onClicked.addListener =>
			chrome.tabs.create url: @base_url

	check: -> 
		@call_jenkins_api @base_url, (jobs) =>
			release_jobs    = new Jobs(job for job in jobs when @is_release.test(job.name))
			components_jobs = new Jobs(job for job in jobs when ! @is_release.test(job.name))
			new_state = @get_new_state(release_jobs, components_jobs)
			if @last_state?
				if @last_state != new_state
					if @last_state == "buildingRelease"
						@build_release_stop(release_jobs)
					else if @last_state == "buildingComponents"
						if new_state != "buildingRelease"
							@build_components_stop(release_jobs, components_jobs)
					@last_state = new_state
					@last_state_change = new Date().getTime()
					console.log new_state
			else 
				@last_state = new_state
				@last_state_change = new Date().getTime()

			if @last_state == "calm"
				title = "Waiting for jobs to start"
				chrome.browserAction.setBadgeText text: ""
			if @last_state == "buildingRelease"
				title = "Building release for " + @format_time(new Date().getTime() - @last_state_change)
				chrome.browserAction.setBadgeText text: "2"
			if @last_state == "buildingComponents"
				title = "Building components for " + @format_time(new Date().getTime() - @last_state_change)
				chrome.browserAction.setBadgeText text: "1"

			chrome.browserAction.setTitle title: title

	build_release_stop: (release_jobs) -> 
		success_jobs = release_jobs.get_succesful_jobs()
		failed_jobs  = release_jobs.get_failed_jobs()
		if ! failed_jobs.is_empty()
			names = failed_jobs.get_names()
			@show_notification("red.png", "Release job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + " failed.")
		else if ! success_jobs.is_empty()
			names = success_jobs.get_names()
			@show_notification("blue.png", "Release job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + " succeeded.")

	build_components_stop: (release_jobs, components_jobs) -> 
		success_jobs = components_jobs.get_succesful_jobs()
		failed_jobs  = components_jobs.get_failed_jobs()
		if ! failed_jobs.is_empty()
			names = failed_jobs.get_names()
			@show_notification("red.png", "Components job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + " failed.")
		else if ! success_jobs.is_empty()
			names = success_jobs.get_names()
			@show_notification("blue.png", "Components job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + 
				" succeeded.<br/>\n<br/>\n" + "Go to Release job: " + release_jobs.get_jobs_names().join(", "))

	show_notification: (icon, message) ->
		@message_queue.push("<img src=\"images/#{icon}\" style=\"float: left\"/>#{message}")
		notification = webkitNotifications.createHTMLNotification "notification.html"
		notification.show()

	get_new_state: (release_jobs, components_jobs) ->
		if ! release_jobs.get_running_jobs().is_empty()
			return "buildingRelease"
		if ! components_jobs.get_running_jobs().is_empty()
			return "buildingComponents"
		return "calm"

	call_jenkins_api: (url, success) ->
		url += "api/json"
		xmlhttp = new XMLHttpRequest;
		xmlhttp.onreadystatechange = -> 
			if @readyState == 4
				if @status == 200
					success JSON.parse(@response)?.jobs
				else
					console.log "can't call API [#{url}]: got [#{@status}] status"
		xmlhttp.open "GET", url, true
		xmlhttp.send null


	format_time: (time) ->
		time = Math.floor(time/1000)
		if time == 0 
			return "no time"
		interval = ["s", "m", "h"]
		str = []
		while time > 0 && interval.length
			rest = time % 60
			time = Math.floor time / 60
			str.push(rest + interval.shift())
		if str.length > 2
			str.shift()
		return str.reverse().join(" ")

	get_next_notification: () ->
		return @message_queue.shift()

	get_refresh_inverval: -> 5


checker = new JenkinsStatusChecker
checker.check()
window.setInterval (() -> checker.check()), checker.get_refresh_inverval() * 1000

## if start release while working on components then "components are broken message is shown"