chrome.extension.sendRequest({"action": "get_clients"}, function(response) {
	var clients = response.clients;
	var names = [];
	for (var username in clients) {
		names.push(username);
	}

	var replace_re = new RegExp('((?:^|>)[^<]*)\\b(' + names.join('|') + ')\\b(?!<sup>)', 'g');
	//var replace_re = new RegExp('(.)\\b(' + names.join('|') + ')\\b(?!<sup>)', 'g');

	var issue_title_elements = document.getElementsByTagName("h3");
	var header_element = issue_title_elements[0];
	replace_in_element(replace_re, clients, issue_title_elements[0]);
	
	var desc_div = document.getElementById("description_full");
	if (desc_div) {
		replace_in_element(replace_re, clients, desc_div);
	}
});

function replace_in_element(replace_re, clients, elem) {
	elem.innerHTML = elem.innerHTML.replace(
		replace_re, 
		function (full_matched, text, username) {
			return text + '<a title="Find client [' + username +
				' - ' + clients[username].type +
				' - ' + clients[username].status +
				'] id [' + clients[username].id + 
				'] (' + clients[username].version +
				')" href="' + clients[username].search_url +
				'" target="_blank">' + username +
				'<sup><img class="rendericon" src="/images/icons/linkext7.gif" height="7" width="7" align="absmiddle" alt="" border="0"/></sup>' +
				'</a>';
		}
	);
}
