function getCurrentSeconds() {
	var now = new Date();
	return Math.floor(now.getTime()/1000);
}

function secondsToString(seconds) {
	var days = Math.floor(seconds / (3600*24));
	seconds %= 3600*24;
	var hours = Math.floor(seconds / 3600);
	seconds %= 3600;
	var minutes = Math.floor(seconds / 60);
	seconds %= 60;
	var arr = [];
	if (days > 0) arr.push(days + "d");
	if (hours > 0) arr.push(hours + "h");
	if (minutes > 0) arr.push(minutes + "m");
	if (seconds > 0) arr.push(seconds + "s");
	if (arr.length > 2) arr = arr.slice(0, 2);
	return arr.join(" ");
}
