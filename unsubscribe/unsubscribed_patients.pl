#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CSVWriter;
use DataSource::DB;

my @clients = @ARGV;
if (@clients) {
	my $data_source = DataSource::DB->new();
	my $start_time = time();
	for my $client_identity (@clients) {
		my $client_data = $data_source->get_client_data_by_db($client_identity);
		unless ($client_data->get_full_type() eq 'ortho_resp') {
			die "unsupported client type [".$client_data->get_full_type()."]";
		}
		printf "database source: client [%s]\n", $client_identity;
		write_unsubscribed_report(
			'_unsubscribed.'.$client_identity.'.csv',
			$client_data,
		);
	}
	printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
	print "Usage: $0 <database1> [database2...]\n";
	exit(1);
}


sub write_unsubscribed_report {
	my ($fn, $client_data) = @_;

	my $report = CSVWriter->new(
		$fn,
		[ 'email', 'fname', 'lname', 'unsubscribed from' ],
	);
	my $moved_unsubscribed_emails  = _get_moved_unsubscribed_emails($client_data);
	for my $email (values %$moved_unsubscribed_emails) {
		$report->write_item($email);
	}
	my $partly_unsubscribed_emails = _get_partly_unsubscribed_emails($client_data);
	for my $email (values %$partly_unsubscribed_emails) {
		unless (exists $moved_unsubscribed_emails->{ lc $email->{'email'} }) {
			$report->write_item($email);
		}
	}
}

sub _get_partly_unsubscribed_emails {
	my ($client_data) = @_;

	my %addresses;
	my $unsubscribed_emails = $client_data->get_unsubscribed_emails();
	for my $unsubscribed_email (@$unsubscribed_emails) {
		my $owner = _get_owner_by_email($client_data, $unsubscribed_email->{'Email'});
		$addresses{ lc $unsubscribed_email->{'Email'} } = {
			'email' => $unsubscribed_email->{'Email'},
			'fname' => ( $owner->{'fname'} || '' ),
			'lname' => ( $owner->{'lname'} || '' ),
			'unsubscribed from' => unsubscribe_type_to_string( $unsubscribed_email->{'Type'} ),
		};
	}
	return \%addresses;
}

sub _get_moved_unsubscribed_emails {
	my ($client_data) = @_;

	my %addresses;
	my $moved_emails = $client_data->get_all_moved_emails();
	for my $moved_email (@$moved_emails) {
		if ($moved_email->{'MovedSource'} eq 'unsubscribe') {
			my $owner = _get_owner_by_email($client_data, $moved_email->{'Email'});
			$addresses{ lc $moved_email->{'Email'} } = {
				'email' => $moved_email->{'Email'},
				'fname' => ( $owner->{'fname'} || '' ),
				'lname' => ( $owner->{'lname'} || '' ),
				'unsubscribed from' => 'everything',
			};

		}
	}

	return \%addresses;
}

sub _get_owner_by_email {
	my ($client_data, $email_address) = @_;

	my $emails = $client_data->get_emails_by_address( $email_address );
	unless (@$emails) {
		$emails = $client_data->get_moved_emails_by_address( $email_address );
	}
	my $owner = undef;
	if (@$emails) {
		my $email = $emails->[0];
		my $responsible = $client_data->get_responsible_by_id( $email->{'RId'} );
		if ($responsible) {
			$owner = {
				'fname' => $responsible->{'FName'},
				'lname' => $responsible->{'LName'},
				'type'  => 'responsible',
			};
		}
		else {
			my ($patient) = $client_data->get_patient_by_id( $email->{'PId'} );
			if ($patient) {
				$owner = {
					'fname' => $patient->{'FName'},
					'lname' => $patient->{'LName'},
					'type'  => 'patient',
				};
			}
			else {
				printf(
					"WARN [%s]: owner is not found\n",
					$email_address,
				);
			}
		}
	}
	else {
		printf("WARN [%s]: email is not found\n", $email_address);
	}
	return $owner;
}

sub unsubscribe_type_to_string {
	my ($type) = @_;

	my @types = (
		[ 1 => 'birthday' ],
		[ 2 => 'holidays' ],
		[ 4 => 'PPN'      ],
	);
	my @r;
	for my $t (@types) {
		if ($type & $t->[0]) {
			push(@r, $t->[1]);
		}
	}
	return join(', ', @r);
}
