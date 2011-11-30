#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw( ../lib );

use DataSource::DB;

my ($first_guid) = @ARGV;

if (defined $first_guid) {
	my %new_guids = map {$_ => 1} @ARGV;
	my $add_count = 0;
	my $data_source = DataSource::DB->new();
	my $voice_config = $data_source->read_config('voice.conf');
	my %all_end_messages = 
		map {$_->{'guid'} => $_}
		grep {exists $new_guids{ $_->{'guid'} }} 
		@{ $voice_config->{'default_end_messages'} };
	unless (keys %all_end_messages) {
		die "invalid guids [".join(', ', keys %new_guids)."] specified";
	}
	print "new guids [".join(', ', keys %all_end_messages)."]\n";
	my $voice_clients = $data_source->get_voice_clients();
	for my $voice_client (@$voice_clients) {
		$add_count += add_end_messages(
			$data_source,
			'professional',
			$voice_client,
			\%all_end_messages,
		)
	}
	printf("[%d] end messages added\n", $add_count);
}
else {
	print "Usage: $0 <new_guid> ...\n";
	exit(1);
}

sub add_end_messages {
	my ($data_source, $voice_type, $voice_client, $all_end_messages) = @_;
	
	my $add_count = 0;
	my $end_messages = $data_source->get_voice_end_messages_by_voice_client(
		$voice_client->{'voice_client_id'},
	);
	@$end_messages = grep {$_->{'voice_type'} eq $voice_type} @$end_messages;
	my %unused_end_messages = %$all_end_messages;
	for my $end_message (@$end_messages) {
		delete $unused_end_messages{ $end_message->{'guid'} };
	}
	for my $new_end_message (values %unused_end_messages) {
		printf(
			"client [%s]: adding [%s] end message\n",
			$voice_client->{'cl_mysql'},
			$new_end_message->{'guid'},
		);
		$data_source->add_voice_end_message(
			$voice_client->{'voice_client_id'},
			$new_end_message->{'title'},  
			$new_end_message->{'text'},
			$new_end_message->{'guid'},
			'professional',
			$new_end_message->{'status'},
		);
		$add_count++;
	}
	return $add_count;
}