function DataGraph(granularity, capacity, dimensions, group_func) {
	this.granularity = granularity;
	this.capacity = capacity;
	this.points = [];
	this.time_border = null;
	this.current_point = null; // index of point in points array
	this.value_granularity = 5;
	this.dimensions = dimensions || 1;
	this.group_func = group_func;
}

// params: (time, data1, ...)
DataGraph.prototype.add_point = function() {
	var time = arguments[0];
	var data_array = [];
	for (var arg_i=1; arg_i<arguments.length; ++arg_i) {
		data_array.push(arguments[arg_i]);
	}
	if (null === this.time_border) {
		this.time_border = time + this.granularity;
	}
	// adding missing points
	while (time >= this.time_border) {
		var missing_value = [];
		for (var i=0; i < this.dimensions; ++i) {
			missing_value.push(-1);
		}
		this._add_new_data_point(missing_value);
		this.time_border += this.granularity;
	}
	if (null === this.current_point) {
		// first point in section
		this._add_new_data_point(data_array);
	}
	else {
		for (var data_index=0; data_index < this.dimensions; ++data_index) {
			if (this.points[this.current_point][data_index] == -1) {
				this.points[this.current_point][data_index] = data_array[data_index];
			}
			else {
				this.points[this.current_point][data_index] = this.group_func(
					this.points[this.current_point][data_index],
					data_array[data_index]
				);
			}
		}
	}
};

DataGraph.prototype.get_point_summary = function (n) {
	var start = this.points.length - n;
	if (start < 0) {
		start = 0;
	}
	var summary = [];
	for (var data_index=0; data_index < this.dimensions; ++data_index) {
		var row_summary = 0;
		for (var point_index = start; point_index < this.points.length; ++point_index) {
			if (this.points[point_index][data_index] != -1) {
				row_summary = this.group_func(
					row_summary,
					this.points[point_index][data_index]
				);
			}
		}
		summary.push(row_summary);
	}
	return summary;
};

DataGraph.prototype._add_new_data_point = function(data) {
	this.points.push(data);
	if (this.points.length > this.capacity) {
		this.points.splice(0, this.points.length - this.capacity);
	}
	this.current_point = this.points.length - 1;
}


DataGraph.prototype.get_chart_data = function() {
	return GraphUtils.encode_chart_array(this.points, this.dimensions);
};

DataGraph.prototype.get_chart_settings = function() {
	var chart_settings = GraphUtils.normalize_chart_data(this.points, this.dimensions, this.value_granularity);
	chart_settings['time_interval'] = this.points.length * this.granularity;
	return chart_settings;
}

