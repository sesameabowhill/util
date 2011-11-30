#!/usr/bin/perl
## $Id: copy_emails_between_db.pl 3443 2010-11-22 17:20:59Z ivan $

use strict;
use warnings;

use Getopt::Long;

use lib qw( ../lib );

use CandidateManager;
use CandidateForVisitor;
use DataSource::DB;
use DataSource::PMSMigrationBackup;
use Logger;
use Script;

my $match_by_pms_id = 0;
my $add_duplicated_phones = 0;
my $load_emails_from_archive = undef;
my $force_from_client_type = undef;
GetOptions(
	'match-by-pms-id!' => \$match_by_pms_id,
	'add-duplicated-phones!' => \$add_duplicated_phones,
);

my ($db_from_param, $db_to, $db_from_connection, $db_to_connection) = @ARGV;

if (defined $db_to) {
	my $logger = Logger->new();

	my ($db_from, $data_source_from) = Script->choose_data_source_by_username($db_from_param, $db_from_connection);
	my $data_source_to = DataSource::DB->new(undef, $db_to_connection);
	$data_source_from->set_read_only(1);
	$data_source_to->set_read_only(1);
	my $client_data_from = $data_source_from->get_client_data_by_db($db_from, $force_from_client_type);
	my $client_data_to   = $data_source_to->get_client_data_by_db($db_to);
	$logger->printf(
		"copy phones from %s [%s] (%s) -> %s [%s] (%s)",
		$client_data_from->get_full_type(),
		$db_from,
		$data_source_from->get_connection_info(),
		$client_data_to->get_full_type(),
		$db_to,
		$data_source_to->get_connection_info(),
	);
	my $start_time = time();

	copy_phones(
		$logger,
		$client_data_from,
		$client_data_to,
		$match_by_pms_id,
		$add_duplicated_phones
	);

	my $result_sql_fn = '_new_phone.'.$db_to.'.sql';
	$logger->printf("write sql commands to [%s]", $result_sql_fn);
	$data_source_to->save_sql_commands_to_file($result_sql_fn);
	$logger->print_category_stat();

	my $work_time = time() - $start_time;
	$logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
}
else {
	print <<USAGE;
Usage: $0 <username_from> <username_to> [db_from_connection] [db_to_connection] [...options]
Special username_from prefix:
    pms_migration_backup: - data should be loaded from pms migration backup files
Options:
    --add-duplicated-phones - add duplicated phones
    --match-by-pms-id - allow to match using PMS id
USAGE
	exit(1);
}


sub copy_phones {
	my ($logger, $client_data_from, $client_data_to, $match_by_pms_id, $add_duplicated_phones) = @_;

	my $added_count = 0;
	my $from_phones = $client_data_from->get_all_phones();
	for my $from_phone (@$from_phones) {
		my $add_phone;
		if ($add_duplicated_phones) {
			$add_phone = 1;
		}
		else {
			if ($client_data_to->phone_is_used( $from_phone->{'number'} )) {
				$logger->printf_slow(
					"SKIP: phone [%s] is already used",
					$from_phone->{'number'},
				);
				$logger->register_category('phone exists');
				$add_phone = 0;
			}
			else {
				$add_phone = 1;
			}
		}
		if ($add_phone) {
			my $candidate_manager = CandidateManager->new(
				{
					($match_by_pms_id ? ( 'by_pms_id' => 1 ) : () ),
					'by_pat_resp' => 3,
					'by_pms_resp' => 4,
					'by_pms_pat' => 5,
					'by_resp' => 6,
					'by_pat' => 7,
				}
			);

			my $from_visitor = $client_data_from->get_visitor_by_id( $from_phone->{'visitor_id'} );
			CandidateForVisitor->match_visitor(
				$candidate_manager,
				$from_visitor,
				$client_data_to
			);

			my ($candidate, $found_by) = $candidate_manager->get_single_candidate_with_priority();
			if (defined $candidate) {
				$logger->printf_slow(
					"ADD: %s by %s",
					$from_phone->{'number'},
					$found_by,
				);
				add_phone_to_visitor(
					$client_data_to,
					$from_phone,
					$candidate,
				);
				$added_count++;
				$logger->register_category('phone added (matched by '.$found_by.')');
			}
			else {
				$logger->printf_slow(
					"SKIP: %s - %s",
					$from_phone->{'number'},
					$candidate_manager->candidates_count_str(),
				);
				$logger->register_category('phone not added (no candidate found)');
			}
		}
	}

	$logger->printf("[%d] of [%d] phones added", $added_count, scalar @$from_phones);
}

sub add_phone_to_visitor {
	my ($client_data, $phone, $candidate) = @_;

	my $visitor = $candidate;

	$client_data->add_phone(
		$visitor->{'id'},
		$phone->{'number'},
		$phone->{'type'},
		$phone->{'sms_active'},
		$phone->{'voice_active'},
		$phone->{'source'},
		$phone->{'entry_datetime'},
	);
}
