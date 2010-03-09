function GraphUtils() {
}


GraphUtils.encode_chart_array = function(arr) {
	var result = "";
	for (var i=0; i<arr.length; ++i) {
		result += GraphUtils.google_chart_encode(arr[i]);
	}
	return result;
};
GraphUtils.normalize_chart_data = function(points, value_granularity) {
	var max_value = 0;
	for (var i=0; i<points.length; ++i) {
		if (points[i] > max_value) {
			max_value = points[i];
		}
	}
	var scaled_data;
	if (0 == max_value) {
		max_value = 1;
	}
	if (0 == (max_value % value_granularity)) {
		max_value += value_granularity;
	}
	else {
		max_value = Math.ceil(max_value / value_granularity) * value_granularity
	}
	scaled_data = [];
	for (var i=0; i<points.length; ++i) {
		scaled_data.push(Math.floor((4095 * points[i])/max_value));
	}
	return {
		'max': max_value,
		'data': GraphUtils.encode_chart_array(scaled_data)
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
