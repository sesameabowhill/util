function ClientStack(capacity) {
	this.capacity = capacity;
	this.active_clients = {};
	this.processed_clients = [];
}

DataGraph.prototype.add_processing_clients = function(time, clients) {
	var current_active = {};
	for (var client_id in clients) {
		if (clients[client_id].is_active) {
			current_active[client_id] = 1;
			if (! client_id in this.active_clients) {
				this.active_clients[client_id] = {
					'id': client_id,
					'start_time': time
				};
			}
		}
	}
	for (var client_id in this.active_clients) {
		if (!client_id in current_active) {
			var cl = this.active_clients[client_id];
			cl.end_time = time;
			this.processed_clients.push(cl)
			delete this.active_clients[client_id];
		}
	}
};

DataGraph.prototype.get_avarage_time = function(time, clients) {
};
