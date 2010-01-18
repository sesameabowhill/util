#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

{
	my $data_source_5 = DataSource::DB->new_5();
	my $data_source_4 = DataSource::DB->new_4();

	my %actions = (
		'hhf_forms' => \&migrate_hhf_forms,
	);

	my ($action, @clients) = @ARGV;
	$action ||= '';

	if (exists $actions{$action} && @clients) {
	    my $start_time = time();
		for my $client_db_5 (@clients) {
			my $client_data_5 = $data_source_5->get_client_data_by_db($client_db_5);
			my $username = $client_data_5->get_username();
			my $db_name = $data_source_4->get_database_by_username($username);
			if (defined $db_name) {
				my $client_data_4 = $data_source_4->get_client_data_by_db($db_name);
				$actions{$action}->($client_data_5, $client_data_4);
			}
			else {
				printf "SKIP [%s]: client is not found sesame4\n";
			}
		}
	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
		my @actions = sort keys %actions;
		print "Usage: $0 <".join('|', @actions)."> <client_db1> ...\n";
		exit(1);
	}
}

sub migrate_hhf_forms {
	my ($client_data_5, $client_data_4) = @_;

	if ($client_data_5->get_hhf_id() eq $client_data_4->get_hhf_id()) {
		my $hhf_id = $client_data_5->get_hhf_id();
		printf "CLIENT [%s]: hhf id [%s]\n", $client_data_5->get_username(), $hhf_id;
		my $forms_4 = $client_data_4->get_all_hhf_forms();
		my %forms_5 = (
			map {_generate_key($_) => $_}
			@{ $client_data_5->get_all_hhf_forms() }
		);
		for my $form (@$forms_4) {
			my $form_key_4 = _generate_key($form);
			unless (exists $forms_5{$form_key_4}) {
				printf "copy form [%s]\n", $form_key_4;
				$client_data_5->add_hhf_form(
					$form->{'filldate'},
					$form->{'fname'},
					$form->{'lname'},
					$form->{'birthdate'},
					$form->{'note'},
					$form->{'signature'},
					$form->{'body'},
				);
			}
		}
	}
	else {
		printf "ERROR [%s]: hhf has different guid\n", $client_data_5->get_username();
	}
}

sub _generate_key {
	my ($data) = @_;

	return join('|', @$data{'filldate', 'fname', 'lname'});
}