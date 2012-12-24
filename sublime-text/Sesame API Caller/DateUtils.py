import re
from datetime import datetime, timedelta

def timestamp_to_string(timestamp):
	epoch = datetime.utcfromtimestamp(0)
	epoch += timedelta(seconds = timestamp)
	return epoch.strftime('%Y-%m-%d %H:%M:%S UTC')

def convert_to_timestamp(dt):
	epoch = datetime.utcfromtimestamp(0)
	delta = dt - epoch
	return (delta.seconds + delta.days * 24 * 3600)

def convert_to_timedelta(delta):
	offset_matched = DELTA_RE.search(delta)
	if offset_matched:
		if offset_matched.group('unit') == 'h':
			return timedelta(hours = int(offset_matched.group('offset')))
		elif offset_matched.group('unit') == 'd':
			return timedelta(days = int(offset_matched.group('offset')))
	return None

DELTA_RE = re.compile('(?P<offset>\d+)(?P<unit>[hd])')
