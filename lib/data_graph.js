function DataGraph() {
	//this.granularity = granularity;
	this.points = [];
	this.start_time = null;
}

DataGraph.prototype.add_point = function(time, data) {
	if (null === this.start_time) {
		this.start_time = time;
	}
	this.points.push([time, data]);
};

DataGraph.prototype.get_chart_data = function(granularity) {
	var compressed_points = [];
	if (this.points.length > 0) {
		var first_time = this.points[0][0];
		this.start_time += Math.floor((first_time - this.start_time)/granularity)*granularity;
		for (var i=0; i<this.points.length; ++i) {
			if (compressed_points.length == 0 || this.points[i][0] >= this.start_time) {
				compressed_points.push(this.points[i][1]);
				var next_i = i + 1;
				if (next_i < this.points.length) {
					this.start_time += granularity;
					while (this.points[next_i][0] > this.start_time) {
						compressed_points.push(0);
						this.start_time += granularity;
					}
				}
			}
			else {
				var last_index = compressed_points.length - 1;
				compressed_points[last_index] = Math.max(compressed_points[last_index], this.points[i][1]);
			}
		}
	}

	var result = "";
	for (var i=0; i<compressed_points.length; ++i) {
		result += this.google_chart_encode(compressed_points[i]);
	}
	return result;
};

DataGraph.prototype.google_chart_encode = function (number) {
	var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-";
	if (number >= alphabet.length * alphabet.length) {
		number = (alphabet.length * alphabet.length ) - 1;
	}
	var first = Math.floor(number / alphabet.length);
	var second = number % alphabet.length;
	return new String(alphabet.charAt(first)) + alphabet.charAt(second);
}
