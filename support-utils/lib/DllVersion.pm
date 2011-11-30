## $Id$

package DllVersion;

use strict;
use warnings;

use Win32::API;
use Encode qw/encode decode/;

sub new {
	my ($class) = @_;

	Win32::API->Import(
		'version.dll',
		'DWORD GetFileVersionInfoSizeA(LPSTR lptstrFilename, LPDWORD lpdwHandle)'
	);
	Win32::API->Import(
		'version.dll',
		'BOOL GetFileVersionInfoA(LPSTR lptstrFilename, DWORD dwHandle, DWORD dwLen, LPVOID lpData)',
	);

	return bless {

	}, $class;
}

sub get_file_version_info {
	my ($self, $filename) = @_;

	my $handler;
	my $version_info_size = GetFileVersionInfoSizeA($filename, $handler);
	if ($version_info_size) {
		my $version_data = " " x $version_info_size;
		if (GetFileVersionInfoA($filename, $handler, $version_info_size, $version_data)) {
			return _parse_version_data($version_data);
		}
		else {
			return undef;
		}
	}
	else {
		return undef;
	}
}

sub _parse_version_data {
	my ($str) = @_;

	$str = decode('UTF-16LE', $str);
	my %params = ($str =~ m/\x01([^\x00]+)\x00{2}([^\x00]+)/g);
	return \%params;
}

1;