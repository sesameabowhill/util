#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;

use lib qw(../lib);

use CandidateManager;
use DataSource::DB;
use Repair::RepairClincheck;
use Script;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'client_data_handler' => \&match_invisalign_patients,
		'save_commands' => '_copy_files_to_shared_accounts.sh',
	}
);

sub match_invisalign_patients {
	my ($logger, $client_data) = @_;

	my $repair_module = Repair::RepairClincheck->new($logger);

	my $shared_client_data = $client_data->get_clients_who_share_invisalign_accounts();
	if (@$shared_client_data) {
		$logger->printf(
			"CLIENT [%s]: shares invisalign accounts with [%s]",
			$client_data->get_username(),
			join(', ', map { $_->get_username() } @$shared_client_data),
		);
		my @all_affected_clients = ($client_data, @$shared_client_data);
		my $all_invisalign_client_ids = get_all_invisalign_client_ids(\@all_affected_clients);
		my $all_case_numbers = get_all_case_numbers(\@all_affected_clients);
		$logger->printf(
			"CLIENT [%s]: [%d] case numbers and [%d] accounts",
			$client_data->get_username(),
			scalar @$all_case_numbers,
			scalar @$all_invisalign_client_ids,
		);

		for my $case_number (@$all_case_numbers) {
			my $file_found_id = get_invisalign_client_by_gif_file(
				$client_data,
				$case_number,
				$all_invisalign_client_ids,
			);
			if (defined $file_found_id) {
				my $from_folder = $client_data->file_path_for_clinchecks($file_found_id);
				for my $id (@$all_invisalign_client_ids) {
					my $to_folder = $client_data->file_path_for_clinchecks($id);
					if ($to_folder ne $from_folder) {
						if (is_gif_file_exists($client_data, $case_number, $id)) {
							$logger->printf_slow("CASE [%s]: file exists in [%s]", $case_number, $to_folder);
							$logger->register_category('case file was already copied');
						}
						else {
							copy_gif_files($logger, $case_number, $from_folder, $to_folder);
						}
					}
				}
			}
			else {
				$logger->printf("CASE [%s]: file not found", $case_number);
				$logger->register_category('case file is not found');
			}
		}
	}
	else {
		$logger->printf(
			"SKIP [%s]: no shared invisalign accounts",
			$client_data->get_username(),
		);
	}
}

sub get_all_invisalign_client_ids {
	my ($clients) = @_;

	my %invisalign_client_ids;
	for my $client (@$clients) {
		my ($ids) = $client->get_invisalign_client_ids();
		for my $id (@$ids) {
			$invisalign_client_ids{$id} = 1;
		}
	}
	return [ keys %invisalign_client_ids ];
}

sub get_all_case_numbers {
	my ($clients) = @_;

	my %case_numbers;
	for my $client (@$clients) {
		my ($patients) = $client->get_all_invisalign_patients();
		for my $patient (@$patients) {
			$case_numbers{ $patient->{'case_number'} } = 1;
		}
	}
	return [ sort {$a <=> $b} keys %case_numbers ];
}

sub get_invisalign_client_by_gif_file {
	my ($client_data, $case_number, $ids) = @_;

	for my $id (@$ids) {
		if (is_gif_file_exists($client_data, $case_number, $id)) {
			return $id;
		}
	}
	return undef;
}

sub is_gif_file_exists {
	my ($client_data, $case_number, $id) = @_;

	my $file_name = File::Spec->join(
		$client_data->file_path_for_clinchecks($id),
		$case_number.'_f.gif',
	);
	return -e $file_name;
}

{
	my %folder_created;

	sub copy_gif_files {
		my ($logger, $case_number, $from_folder, $to_folder) = @_;

		unless (exists $folder_created{$to_folder}) {
			unless (-d $to_folder) {
				$logger->add_command(qq(mkdir -pv "$to_folder"));
				$logger->register_category('create missing folder');
			}
			$folder_created{$to_folder} = 1;
		}
		$logger->printf_slow(
			"COPY [%s]: from [%s] to [%s]",
			$case_number,
			$from_folder,
			$to_folder,
		);
		$logger->register_category('copy gif files');
		$logger->add_command(qq(cp -v $from_folder/$case_number* $to_folder));
	}
}