class JenkinsStatusChecker
	constructor: ->
		# calm, buildingComponents, buildingRelease
		@last_state = null
		@last_state_change = null
		@is_release = /-pp$/
		@is_running = /_anime$/
		@is_success = /^blue$/
		@base_url = "https://ci.sesamecom.com/jenkins/view/Legacy/"
		@message_queue = []
	check: -> 
		@call_jenkins_api @base_url, (jobs) =>
			new_state = @get_new_state(jobs)
			if @last_state?
				if @last_state != new_state
					if @last_state == "buildingRelease"
						@build_release_stop(jobs)
					else if @last_state == "buildingComponents"
						@build_components_stop(jobs)
					@last_state = new_state
					@last_state_change = new Date().getTime()

					console.log new_state
			else 
				@last_state = new_state
				@last_state_change = new Date().getTime()

			if @last_state == "calm"
				title = "Waiting for jobs to start"
			if @last_state == "buildingRelease"
				title = "Building release for " + @format_time(new Date().getTime() - @last_state_change)
			if @last_state == "buildingComponents"
				title = "Building components for " + @format_time(new Date().getTime() - @last_state_change)

			chrome.browserAction.setTitle title: title

	build_release_stop: (jobs) -> 
		success_jobs = (job for job in jobs when @is_release.test(job.name) && @is_success.test(job.color))
		failed_jobs  = (job for job in jobs when @is_release.test(job.name) && ! @is_success.test(job.color))
		if failed_jobs.length
			names = @get_jobs_names failed_jobs
			@show_notification("red.png", "Release job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + " failed.")
		else if success_jobs.length
			names = @get_jobs_names success_jobs
			@show_notification("blue.png", "Release job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + " succeeded.")

	build_components_stop: (jobs) -> 
		success_jobs = (job for job in jobs when ! @is_release.test(job.name) && @is_success.test(job.color))
		failed_jobs  = (job for job in jobs when ! @is_release.test(job.name) && ! @is_success.test(job.color))
		if failed_jobs.length
			names = @get_jobs_names failed_jobs
			@show_notification("red.png", "Components job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + " failed.")
		else if success_jobs.length
			release_jobs  = (job for job in jobs when @is_release.test(job.name))
			names = @get_jobs_names success_jobs
			@show_notification("blue.png", "Components job" + (if names.length==1 then "" else "s") + " " + names.join(", ") + 
				" succeeded.<br/>\n" + "Go to Release job: " + @get_jobs_names(release_jobs).join(", "))

	show_notification: (icon, message) ->
		@message_queue.push("<img src=\"images/#{icon}\"/>#{message}")
		notification = webkitNotifications.createHTMLNotification "notification.html"
		notification.show()

	get_jobs_names: (jobs) ->
		return ("<a href=\"#{job.url}/lastBuild/\">#{job.name}</a>" for job in jobs)

	get_new_state: (jobs) ->
		running_release_jobs    = (job for job in jobs when @is_release.test(job.name) && @is_running.test(job.color))
		running_components_jobs = (job for job in jobs when ! @is_release.test(job.name) && @is_running.test(job.color))
		if running_release_jobs.length
			return "buildingRelease"
		if running_components_jobs.length
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


checker = new JenkinsStatusChecker
window.setInterval (() -> checker.check()), 1*1000