function CommandFinder(commands) {
	var key_map = {
		"nodes": {}
	};
	commands.forEach(function (cmd) {
		var letters = cmd.split("");
		var current_node = key_map;
		letters.forEach(function (letter) {
			if (!(letter in current_node.nodes)) {
				current_node.nodes[letter] = {
					"nodes": {}
				};
			}
			current_node = current_node.nodes[letter];
		});
		current_node.matched = cmd;
	});
	var suggestions = {};
	this._make_suggestion(key_map, suggestions, "");
	this.command_map = suggestions;
}

CommandFinder.prototype.get_suggestions = function (word) {
	if (word in this.command_map) {
		return this.command_map[word].sort();
	}
	else {
		return [];
	}
};

CommandFinder.prototype._make_suggestion = function (nodes, suggestions, path) {
	var all_commands = [];
	for (letter in nodes.nodes) {
		var next_path = path + letter;
		var next_commands = this._make_suggestion(nodes.nodes[letter], suggestions, next_path);
		suggestions[next_path] = next_commands;
		all_commands = all_commands.concat(next_commands);
	}
	if ("matched" in nodes) {
		all_commands = [ nodes.matched ];
	}
	return all_commands;
};
