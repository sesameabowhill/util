function GraphUtils() {
}


GraphUtils.encode_chart_array = function(arr, dimensions) {
	var series = []
	for (var data_index=0; data_index < dimensions; ++data_index) {
		var result = "";
		for (var i=0; i<arr.length; ++i) {
			result += GraphUtils.google_chart_encode(arr[i][data_index]);
		}
		series.push(result);
	}
	return series.join("|");
};
GraphUtils.normalize_chart_data = function(points, dimensions, value_granularity) {
	var max_value = 0;
	for (var i=0; i<points.length; ++i) {
		for (var data_index=0; data_index < dimensions; ++data_index) {
			if (points[i][data_index] > max_value) {
				max_value = points[i][data_index];
			}
		}
	}
	if (0 == max_value) {
		max_value = 1;
	}
	if (0 == (max_value % value_granularity)) {
		max_value += value_granularity;
	}
	else {
		max_value = Math.ceil(max_value / value_granularity) * value_granularity
	}
	var scaled_data = [];
	for (var i=0; i<points.length; ++i) {
		var data = [];
		for (var data_index=0; data_index < dimensions; ++data_index) {
			data.push(Math.floor((4095 * points[i][data_index])/max_value));
		}
		scaled_data.push(data);
	}
	return {
		'max': max_value,
		'data': GraphUtils.encode_chart_array(scaled_data, dimensions)
	};
};

GraphUtils.google_chart_encode = function (number) {
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
};
