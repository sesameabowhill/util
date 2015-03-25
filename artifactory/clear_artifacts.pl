#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use JSON;
use Getopt::Long;

my ($list, $repository, $group_id);
GetOptions(
	'list!' => \$list,
	'repository=s' => \$repository,
	'group-id=s' => \$group_id,
);

$repository //= 'libs-release-local';
$group_id //= 'com.sesamecom';

my @versions = @ARGV;

my $logger = Logger->new(1);

if ($list) {
	$logger->info("list versions from [%s]", $repository);
	
	my $versions = group_by_verion(search($logger, $repository, $group_id));
	for my $version (sort keys %$versions) {
		my $count = @{ $versions->{$version} };
		$logger->info("%s - %d artifact%s", $version, $count, ($count == 1 ? "" : "s"));
	}
} elsif (@versions) {
	$logger->info("delete artifacts from [%s] version%s [%s]", $repository, (@versions == 1 ? '' : 's'), join(', ', @versions));
	my $total_count = 0;
	for my $version (@versions) {
		my $urls = search_folders($logger, $repository, $group_id, $version);
		$logger->info("%d artifact%s to delete in [%s] version", scalar @$urls, (@$urls == 1 ? '' : 's'), $version);
		my $count = @$urls;
		for my $u (sort @$urls) {
			$u =~ s{api/storage/}{};
            # Delete folder (deleting only files left empty folders)
#            $logger->info("folder: $u");
			$logger->info("delete [%s] (%d to go)", (split('/', $u))[-2].'/'.(split('/', $u))[-1], --$count);
			delete_artifact($u);
			$total_count ++;
		}
	}
	$logger->info("%d artifact%s deleted", $total_count, ($total_count == 1 ? "" : "s"));
} else {
	print <<USAGE;
Usage: $0 --list|<version...> [options...]
Options:
  --repository=libs-release-local
  --group-id=com.sesamecom
USAGE
	exit(2);
}

sub group_by_verion {
    my ($urls) = @_;

    my %versions;
    for my $u (@$urls) {
		my $version = (split('/', $u))[-2];
		push(@{$versions{$version}}, $u);
    }
    return \%versions;
}

sub search {
    my ($logger, $repository, $group_id, $version) = @_;

    my $result = api_call("http://artifactory.sesamecom.com/artifactory/api/search/gavc?g=".$group_id."&repos=".$repository.(defined $version ? "&v=". $version : ""));

    $result //= { 'results' => [] };
    $result = [ map {$_->{'uri'}} @{ $result->{'results'} } ];
    unless (@$result) {
	    $logger->info("no artifacts found");
    }
    return $result;
}
sub search_folders {
    my ($logger, $repository, $group_id, $version) = @_;
    
    my $result = search($logger, $repository, $group_id, $version);
    my %folders = ();
    foreach my $url (@$result) {
        my @parts = split /\//, $url; 
        $url = join( "/", @parts[0 .. $#parts-1] );
        $folders{$url} = 1;
    }
    my @r = keys %folders;
    unless (@r) {
	    $logger->info("no folder artifacts found");
    }
    return \@r;
}

sub delete_artifact {
    my ($url) = @_;
	
	my $ua = get_user_agent();
	my $response = $ua->delete($url);
	if ($response->is_success()) {
		return 1;
	} else {
		die $response->status_line();
	}
}

sub get_details {
    my ($uri) = @_;
	
	return api_call($uri);
}

sub api_call {
    my ($url) = @_;
	
	my $ua = get_user_agent();
	my $response = $ua->get($url);
	if ($response->is_success()) {
		return decode_json($response->decoded_content());
	} else {
		if ($response->code() == 404) {
			return undef;
		} else {
			die $response->status_line();
		}
	}
}

sub get_user_agent {

	my $ua = LWP::UserAgent->new();
	$ua->default_header("Authorization", "Basic ZGVwbG95OmQzcGwweQ==");
	$ua->timeout(300);
	return $ua;
}

package Logger;

sub new {
    my ($class, $print) = @_;
	
	return bless {
		'print' => $print,
		'lines' => [],
	}, $class;
}

sub info {
    my ($self, $msg) = (shift, shift);
	
	if ($self->{'print'}) {
	    printf $msg."\n", @_;
	} else {
		push(@{ $self->{'lines'} }, sprintf($msg, @_));
	}
}

sub print_all_to_stderr {
    my ($self) = @_;
	
	for my $line (@{ $self->{'lines'} }) {
		print STDERR $line."\n";
	}
	$self->{'lines'} = [];
}
