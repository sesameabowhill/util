function ClientStack(capacity) {
	this.capacity = capacity;
	this.active_clients = {};
	this.processed_clients = [];
}

ClientStack.prototype.add_processing_clients = function(time, clients) {
	var current_active = {};
	for (var client_id in clients) {
		if (clients[client_id].is_active) {
			current_active[client_id] = 1;
			if (!(client_id in this.active_clients)) {
				this.active_clients[client_id] = {
					'id': client_id,
					'start_time': time
				};
			}
		}
	}
	for (var client_id in this.active_clients) {
		if (!(client_id in current_active)) {
			var cl = this.active_clients[client_id];
			cl['process_time'] = time - cl.start_time;
			this.processed_clients.push(cl)
			delete this.active_clients[client_id];
		}
	}
	this.processed_clients = this.processed_clients.sort(function (a, b) {
		return b.start_time - a.start_time;
	});
	if (this.processed_clients.length > this.capacity) {
		this.processed_clients = this.processed_clients.slice(0, this.capacity);
	}
};

ClientStack.prototype.get_average_processing_time = function() {
	var sum = 0;
	for(var i=0; i<this.processed_clients.length; ++i) {
		sum += this.processed_clients[i].process_time;
	}
	return (this.processed_clients.length > 0 ? Math.ceil(sum/this.processed_clients.length) : null);
};

ClientStack.prototype.get_all_processing_time_time = function() {
	var time = [];
	for(var i=0; i<this.processed_clients.length; ++i) {
		time.push(this.processed_clients[i].process_time);
	}
	return time;
};
