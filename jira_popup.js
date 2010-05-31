chrome.extension.sendRequest({"action": "get_clients"}, function(response) {
	var clients = response.clients;
	var names = [];
	for (var username in clients) {
		names.push(username);
	}

	var replace_re = new RegExp('((?:^|>)[^<]*?)\\b(' + names.join('|') + ')\\b(?!<sup>)', 'g');
	//var replace_re = new RegExp('(.)\\b(' + names.join('|') + ')\\b(?!<sup>)', 'g');

	var header_element = document.getElementById("issue_header_summary");
	// remove link from the title
	var title_html = header_element.innerHTML;
	title_html = title_html.replace(/^\s*<a[^>]+>/, '');
	title_html = title_html.replace(/<\/a>\s*$/g, '');
	header_element.innerHTML = title_html;
	replace_in_element(replace_re, clients, header_element);
	
	var desc_div = document.getElementById("description-full");
	if (desc_div) {
		replace_in_element(replace_re, clients, desc_div);
	}
});

init_accesskeys();

function init_accesskeys() {
	add_accesskey("log-work", "w");
	add_accesskey("move-issue", "m");
	add_accesskey("link-issue", "l");
	add_accesskey("clone-issue", "c");
}

function add_accesskey(elem_id, key) {
	var elem = document.getElementById(elem_id);
	if (null !== elem) {
		elem.accessKey = key;
		console.log("access: #"+elem_id+"-"+key);
	}
}

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
