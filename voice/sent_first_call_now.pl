#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;
use DateUtils;

use constant 'SENT_IN_SECONDS' => 30;

my ($client_db) = @ARGV;

if (defined $client_db) {
	my $data_source = DataSource::DB->new();
	my $client_data = $data_source->get_client_data_by_db($client_db);
	printf "client [%s]\n", $client_db;
	my $first_call = get_first_queued_call($client_data);
	if (defined $first_call) {
		my $send_dt = DateUtils->now();
		$send_dt->add_seconds(SENT_IN_SECONDS);
		my $xml_request = $first_call->{'xml_request'};
		$xml_request =~ s{(<UTCScheduledDateTime>)[^<]+(</UTCScheduledDateTime>)}{$1.$send_dt->as_voice_utc().$2}e;

		$client_data->set_voice_queued_call_time(
			$first_call->{'id'},
			$send_dt->as_mysql_datetime(),
			$xml_request,
		);
		printf(
			"REQUEUED: call [%s] will be sent in [%d] seconds at [%s]\n",
			$first_call->{'unique_key'},
			SENT_IN_SECONDS,
			$send_dt->as_mysql_datetime(),
		);
	}
	else {
		print "SKIP: no calls in queue\n";
	}

}
else {
	print "Usage: $0 <client_db>\n";
	exit(1);
}

sub get_first_queued_call {
	my ($client_data) = @_;

	my $calls = $client_data->get_all_voice_queued_calls();
	@$calls = sort {$a->{'id'} <=> $b->{'id'}} @$calls;
	if (@$calls) {
		my $first_call = $calls->[0];
		printf "return first call [%s] of [%d]\n", $first_call->{'unique_key'}, scalar @$calls;
		return $first_call;
	}
	else {
		return undef;
	}
}

