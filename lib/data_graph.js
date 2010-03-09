function DataGraph(granularity, capacity) {
	this.granularity = granularity;
	this.capacity = capacity;
	this.points = [];
	this.time_border = null;
	this.current_point = null;
	this.value_granularity = 5;
}

DataGraph.prototype.add_point = function(time, data) {
	if (null === this.time_border) {
		this.time_border = time + this.granularity;
	}
	while (time >= this.time_border) {
		this._add_new_data_point(-1);
		this.time_border += this.granularity;
	}
	if (null === this.current_point) {
		// first point in section
		this._add_new_data_point(data);
	}
	else {
		this.points[this.current_point] = Math.max(
			this.points[this.current_point],
			data
		);
	}
};

DataGraph.prototype._add_new_data_point = function(data) {
	this.points.push(data);
	if (this.points.length > this.capacity) {
		this.points.splice(0, this.points.length - this.capacity);
	}
	this.current_point = this.points.length - 1;
}


DataGraph.prototype.get_chart_data = function() {
	return GraphUtils.encode_chart_array(this.points);
};

DataGraph.prototype.get_chart_settings = function() {
	var chart_settings = GraphUtils.normalize_chart_data(this.points, this.value_granularity);
	chart_settings['time_interval'] = this.points.length * this.granularity;
	return chart_settings;
}

