#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use List::Util qw( max );

use lib '../lib';

use DllVersion;

my @files = @ARGV;
if (@files) {
	my $new_files = get_new_files(\@files);
	my $old_files = get_current_files();
	my %merged_files = %$old_files;
	for my $file (keys %$new_files) {
		if (exists $old_files->{$file} && $old_files->{$file}{'version'} eq $new_files->{$file}{'version'}) {
			## skip with same version
		}
		else {
			$merged_files{$file} = $new_files->{$file};
		}
	}
	print_data(\%merged_files);
}
else {
	print "Usage: $0 <file1.dll> ...\n";
	exit(1);
}

sub get_new_files {
	my ($files) = @_;

	my $version_getter = DllVersion->new();

	my %unique_files;
	for my $file (@$files) {
		my $version_info = $version_getter->get_file_version_info($file);
		if (defined $version_info) {
			$unique_files{lc $file} = {
				'name'    => $file,
				'version' => $version_info->{'FileVersion'},
				'url'     => 'new',
			};
		}
	}
	return \%unique_files;
}

sub get_current_files {

	my %unique_files;
	while (<DATA>) {
		my ($name, $version, $url) = (m/name="([^"]+)"\s+version="([^"]+)"\s+url="([^"]+)"/);
		if (defined $name) {
			$unique_files{lc $name} = {
				'name'    => $name,
				'version' => $version,
				'url'     => 'old',
			};
		}
	}
	return \%unique_files;
}

sub print_data {
	my ($files) = @_;

	my @names = sort keys %$files;
	my $max_name_size    = max(map {length $files->{$_}{'name'}}    @names);
	my $max_version_size = max(map {length $files->{$_}{'version'}} @names);
	for my $file (@names) {
		printf(
			qq(<module name="%s"%s  version="%s"%s  url="%s" %s/>\n),
			$files->{$file}{'name'},
			" " x ($max_name_size - length $files->{$file}{'name'}),
			$files->{$file}{'version'},
			" " x ($max_version_size - length $files->{$file}{'version'}),
			( $files->{$file}{'url'} eq 'new' ?
				'https://www4.orthosesame.com/extractor-updates/new_core/' :
				'https://www4.orthosesame.com/extractor-updates/'
			) . $files->{$file}{'name'},
			( $file eq 'sesameupgrade.exe' ?
				'force="1" ' :
				''
			)
		);
	}
}

__DATA__
		<module name="DentechExtractor.dll"                version="1.0.0.7"   url="https://www4.orthosesame.com/extractor-updates/DentechExtractor.dll" />
		<module name="Dentrix.dll"                         version="6.2.0.26"  url="https://www4.orthosesame.com/extractor-updates/Dentrix.dll" />
		<module name="DentrixExtractorResource.dll"        version="6.1.0.2"   url="https://www4.orthosesame.com/extractor-updates/DentrixExtractorResource.dll" />
		<module name="DolphinManagement.dll"               version="5.1.0.25"  url="https://www4.orthosesame.com/extractor-updates/DolphinManagement.dll" />
		<module name="EagleSoft.dll"                       version="6.1.0.20"  url="https://www4.orthosesame.com/extractor-updates/EagleSoft.dll" />
		<module name="EagleSoftExtractorResource.dll"      version="1.0.0.3"   url="https://www4.orthosesame.com/extractor-updates/EagleSoftExtractorResource.dll" />
		<module name="EmailCollector.exe"                  version="6.3.0.2"   url="https://www4.orthosesame.com/extractor-updates/EmailCollector.exe" />
		<module name="EMailCollectorPropPage.dll"          version="6.3.1.3"   url="https://www4.orthosesame.com/extractor-updates/EMailCollectorPropPage.dll" />
		<module name="EMailCollectorPropPageOle.dll"       version="6.3.0.1"   url="https://www4.orthosesame.com/extractor-updates/EMailCollectorPropPageOle.dll" />
		<module name="EMailCollectorPropPageResource.dll"  version="6.3.0.0"   url="https://www4.orthosesame.com/extractor-updates/EMailCollectorPropPageResource.dll" />
		<module name="NewHorizon.dll"                      version="5.0.1.9"   url="https://www4.orthosesame.com/extractor-updates/NewHorizon.dll" />
		<module name="OASYS.dll"                           version="5.1.0.11"  url="https://www4.orthosesame.com/extractor-updates/OASYS.dll" />
		<module name="OrthoEase.dll"                       version="5.1.0.8"   url="https://www4.orthosesame.com/extractor-updates/OrthoEase.dll" />
		<module name="OrthoTracOffice.dll"                 version="5.1.0.18"  url="https://www4.orthosesame.com/extractor-updates/OrthoTracOffice.dll" />
		<module name="OrthotracClassic.dll"                version="5.1.1.19"  url="https://www4.orthosesame.com/extractor-updates/OrthotracClassic.dll" />
		<module name="OrthoTracOfficeSQLExtractor.dll"     version="1.0.0.10"  url="https://www4.orthosesame.com/extractor-updates/OrthotracOfficeSQLExtractor.dll" />
		<module name="PracticeWorks.dll"                   version="5.0.0.17"  url="https://www4.orthosesame.com/extractor-updates/PracticeWorks.dll" />
		<module name="Sesame.exe"                          version="6.3.2.46"  url="https://www4.orthosesame.com/extractor-updates/Sesame.exe" />
		<module name="SesamePI.exe"                        version="6.3.2.20"  url="https://www4.orthosesame.com/extractor-updates/SesamePI.exe" />
		<module name="SesamePropPage.dll"                  version="6.3.2.11"  url="https://www4.orthosesame.com/extractor-updates/SesamePropPage.dll" />
		<module name="SesamePropPageOle.dll"               version="6.3.1.1"   url="https://www4.orthosesame.com/extractor-updates/SesamePropPageOle.dll" />
		<module name="SesamePropPageResource.dll"          version="6.3.1.1"   url="https://www4.orthosesame.com/extractor-updates/SesamePropPageResource.dll" />
		<module name="SesameScheduler.exe"                 version="6.4.1.8"   url="https://www4.orthosesame.com/extractor-updates/SesameScheduler.exe" />
		<module name="SesameUpgrade.exe"                   version="6.3.1.10"  url="https://www4.orthosesame.com/extractor-updates/SesameUpgrade.exe" />
		<module name="topsXtreme.dll"                      version="5.1.0.11"  url="https://www4.orthosesame.com/extractor-updates/topsXtreme.dll" />
