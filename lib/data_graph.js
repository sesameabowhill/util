function DataGraph(granularity, capacity) {
	this.granularity = granularity;
	this.capacity = capacity;
	this.points = [];
	this.time_border = null;
	this.current_point = null;
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
	return this._encode_chart_array(this.points);
};

DataGraph.prototype._encode_chart_array = function(arr) {
	var result = "";
	for (var i=0; i<arr.length; ++i) {
		result += this.google_chart_encode(arr[i]);
	}
	return result;
};

DataGraph.prototype.get_chart_settings = function() {
	var max_value = 0;
	for (var i=0; i<this.points.length; ++i) {
		if (this.points[i] > max_value) {
			max_value = this.points[i];
		}
	}
	var scaled_data;
	if (max_value == 0) {
		max_value = 1;
	}
	scaled_data = [];
	for (var i=0; i<this.points.length; ++i) {
		scaled_data.push(Math.floor((4095 * this.points[i])/max_value));
	}
	return {
		'max': max_value,
		'time_interval': this.points.length * this.granularity,
		'data': this._encode_chart_array(scaled_data)
	};
}

DataGraph.prototype.google_chart_encode = function (number) {
	if (number == -1) {
		return '__';
	}
	else {
		var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-.";
		if (number >= alphabet.length * alphabet.length) {
			number = ( alphabet.length * alphabet.length ) - 1;
		}
		var first = Math.floor(number / alphabet.length);
		var second = number % alphabet.length;
		return new String(alphabet.charAt(first)) + alphabet.charAt(second);
	}
}
