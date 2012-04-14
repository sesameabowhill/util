window.onload = ->
	message = chrome.extension.getBackgroundPage().checker.get_next_notification()
	document.getElementsByTagName("body")[0].innerHTML = message