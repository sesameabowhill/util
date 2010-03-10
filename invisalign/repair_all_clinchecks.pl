#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;

use lib '../lib';

use DataSource::DB;
use CandidateManager;


{
	my $data_access = DataSource::DB->new();
	$data_access->set_read_only(1);
	my $start_time = time();

	my $case_numbers = $data_access->get_all_case_numbers();
	@$case_numbers = sort {$a <=> $b} @$case_numbers;
	for my $case_number (@$case_numbers) {
		repair_case_number($data_access, $case_number);
	}

	my $work_time = time() - $start_time;
	my $fn = "_repair_all_clinchecks.sql";
	printf "write repair commands to [$fn]\n";
	$data_access->save_sql_commands_to_file($fn);
	my $stat = $data_access->get_categories_stat();
	for my $category (sort keys %$stat) {
		printf("%s - %d\n", $category, $stat->{$category});
	}
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;

}


sub repair_case_number {
	my ($data_access, $case_number) = @_;

	my $inv_cl_ids = $data_access->get_invisalign_client_ids_by_case_number($case_number);
	my $clients_inv = get_client_by_invisalign_ids($data_access, $inv_cl_ids);
	if (@$clients_inv > 1) {
		$data_access->add_category('case_number is not unique for patient');
		die "TODO: remove duplicated records";
	}
	else {
		my $icp_cl_ids = $data_access->get_invisalign_processing_client_ids_by_case_number($case_number);
		my $clients_icp = get_client_by_invisalign_ids($data_access, $icp_cl_ids);
		if (@$clients_icp > 1) {
			$data_access->add_category('case_number is not unique for processing patient');
			die "TODO: remove duplicated records";
		}
		else {
			if (@$clients_icp == 1 && @$clients_inv == 1) {
				if ($clients_icp->[0]->get_id() eq $clients_inv->[0]->get_id()) {
					repair_clincheck_for_single_client(
						$data_access,
						$case_number,
						$icp_cl_ids->[0],
						$inv_cl_ids->[0],
						$clients_icp->[0],
					);
				}
				else {
					repair_clincheck_for_two_clients(
						$data_access,
						$case_number,
						$icp_cl_ids->[0],
						$inv_cl_ids->[0],
						$clients_icp->[0],
						$clients_inv->[0],
					);
				}
			}
			elsif (@$clients_icp > 0) {
				repair_clincheck_with_one_icp_client(
					$data_access,
					$case_number,
					$icp_cl_ids->[0],
					$clients_icp->[0],
				);
			}
			elsif (@$clients_inv > 0) {
				repair_clincheck_with_one_inv_client(
					$data_access,
					$case_number,
					$inv_cl_ids->[0],
					$clients_inv->[0],
				);
			}
			else {
				die "case number is not posible";
			}
		}
	}

	#printf("case [%s]\n", $case_number);
}

sub repair_clincheck_for_single_client {
	my ($data_access, $case_number, $icp_client_id, $inv_client_id, $client_data) = @_;

	my $good_inv_ids = get_invisalign_ids_with_image(
		$client_data,
		$case_number,
		[ $icp_client_id, $inv_client_id ],
	);
	if (@$good_inv_ids) {
		if ($icp_client_id eq $inv_client_id) {
			my $done_str = repair_processed_clincheck($client_data, $case_number);
			$data_access->add_category("clincheck with single client$done_str");
		}
		else {
			#printf("case [%s]\n", $case_number);
			fix_change_invisalign_id($client_data, $case_number, $good_inv_ids->[0]);
			my $done_str = repair_processed_clincheck($client_data, $case_number);
			$data_access->add_category("clincheck with different invisalign client$done_str");
		}
	}
	else {
		my $done_str = fix_remove_clincheck($client_data, $case_number);
		print "case [$case_number]: file is missing\n";
		$data_access->add_category("clincheck file is missing$done_str");
	}
}

sub repair_clincheck_for_two_clients {
	my ($data_access, $case_number, $icp_client_id, $inv_client_id, $client_data_by_icp, $client_data_by_inv) = @_;

#	my $patient = $client_data_by_inv->get_invisalign_patient($case_number);
#	my $pat_id_in_inv_client = match_to_sesame_patient($client_data_by_inv, $patient);
#	my $pat_id_in_icp_client = match_to_sesame_patient($client_data_by_icp, $patient);
#
#	if (defined $pat_id_in_icp_client) {
#		if (defined $pat_id_in_inv_client) {
#			## skip
#		}
#		else {
#			##
#		}
#	}
#	else {
#		if (defined $pat_id_in_inv_client) {
#
#		}
#		else {
#
#		}
#	}


#	my $good_icp_ids = get_invisalign_ids_with_image(
#		$client_data_by_icp,
#		$case_number,
#		[ $icp_client_id ],
#	);
#
#	my $good_inv_ids = get_invisalign_ids_with_image(
#		$client_data_by_inv,
#		$case_number,
#		[ $inv_client_id ],
#	);
#
#	if (@$good_icp_ids || @$good_inv_ids) {
#
#	}
#	else {
#		$data_access->add_category('clincheck file is missing');
#		fix_remove_clincheck($client_data, $case_number);
#		print "case [$case_number]: file is missing\n";
#	}


	$client_data_by_icp->delete_invisalign_patient($case_number);
	$client_data_by_inv->delete_invisalign_patient($case_number);
	$client_data_by_icp->delete_invisalign_processing_patient($case_number);
	$client_data_by_inv->delete_invisalign_processing_patient($case_number);

	print "case [$case_number]: two different clients\n";
	$data_access->add_category('clincheck with two clients');
}

sub repair_clincheck_with_one_icp_client {
	my ($data_access, $case_number, $icp_client_id, $client_data) = @_;

	my $done_str = fix_remove_clincheck($client_data, $case_number, 1);
	print "case [$case_number]: invisalign patient is missing$done_str\n";
	$data_access->add_category("clincheck with icp client$done_str");
}

sub repair_clincheck_with_one_inv_client {
	my ($data_access, $case_number, $inv_client_id, $client_data) = @_;

	my $done_str = fix_remove_clincheck($client_data, $case_number);
	print "case [$case_number]: processing patient is missing$done_str\n";
	$data_access->add_category("clincheck with inv client$done_str");
}

sub repair_processed_clincheck {
	my ($client_data, $case_number) = @_;

	my @done;
	unless ($client_data->is_invisalign_patient_processed($case_number)) {
		$client_data->set_invisalign_processing_patient_processed($case_number);
		push(@done, 'fix processed');
	}
	my $patient = $client_data->get_invisalign_patient($case_number);
	unless (defined $patient->{'patient_id'}) {
		my $sesame_patient_id = match_to_sesame_patient(
			$client_data,
			$patient,
		);
		if (defined $sesame_patient_id) {
			push(@done, 'sesame patient is found');
			$client_data->set_sesame_patient_for_invisalign_patient(
				$case_number,
				$sesame_patient_id,
			);
			printf(
				"case [%s]: matched patient [%s %s] to [%s]\n",
				$case_number,
				$patient->{'fname'},
				$patient->{'lname'},
				$sesame_patient_id,
			);
		}
		else {
			push(@done, "can't find sesame patient");
		}
	}
	return (@done?' ('.join(', ', @done).')':'');
}

sub fix_remove_clincheck {
	my ($client_data, $case_number, $skip_invisalign_patient) = @_;

	my @done;
	unless ($skip_invisalign_patient) {
		push(@done, 'delete invisalign patient');
		$client_data->delete_invisalign_patient($case_number);
	}
	unless ($client_data->is_invisalign_patient_processed($case_number)) {
		push(@done, 'delete processing patient');
		$client_data->delete_invisalign_processing_patient($case_number);
	}
	return (@done?' ('.join(', ', @done).')':'');
}

sub fix_change_invisalign_id {
	my ($client_data, $case_number, $invisalign_id) = @_;

	$client_data->set_invisalign_client_id_for_invisalign_patient($case_number, $invisalign_id);
}


sub match_to_sesame_patient {
	my ($client_data, $inv_patient) = @_;

	my $sesame_patients = $client_data->get_cached_data(
		'_get_all_sesame_patients',
		sub {
			return get_all_sesame_patients($client_data);
		},
	);
	my ($sesame_fname) = ($inv_patient->{'fname'} =~ $sesame_patients->{'fname_re'});
	my ($sesame_lname) = ($inv_patient->{'lname'} =~ $sesame_patients->{'lname_re'});
	if (defined $sesame_fname && defined $sesame_lname) {
		my $pids = $sesame_patients->{'all_names'}{$sesame_fname}{$sesame_lname};
		if (defined $pids && @$pids == 1) {
			return $pids->[0];
		}
	}
	return undef;
}

sub get_all_sesame_patients {
	my ($client_data) = @_;

	printf "CLIENT [%s]: get all patient for matching\n", $client_data->get_username();
	$client_data->set_approx_search(1);
	my $sesame_patients = $client_data->get_all_patients();
	my (%all_names, %fname, %lname);
	for my $sesame_patient (@$sesame_patients) {
		$fname{ $sesame_patient->{'FName'} }++;
		$lname{ $sesame_patient->{'LName'} }++;
		push(
			@{ $all_names{ $sesame_patient->{'FName'} }{ $sesame_patient->{'LName'} } },
			$sesame_patient->{'PId'}
		);
	}
	my $fname_re = '\b('.join('|', map {quotemeta($_)} sort keys %fname).')\b';
	my $lname_re = '\b('.join('|', map {quotemeta($_)} sort keys %lname).')\b';
	printf "CLIENT [%s]: [%d] patients found\n", $client_data->get_username(), scalar @$sesame_patients;

	return {
		'fname_re' => qr/$fname_re/,
		'lname_re' => qr/$lname_re/,
		'all_names' => \%all_names,
	};
}

sub get_invisalign_ids_with_image {
	my ($client_data, $case_number, $invisalign_ids) = @_;

	my @good_ids;
	for my $id (@$invisalign_ids) {
		my $file = $client_data->file_path_for_invisalign_comment($id, $case_number);
		if (-f $file) {
			push(@good_ids, $id);
		}
	}
	return \@good_ids;
}

{
	my %clients;
	sub get_client_by_invisalign_ids {
		my ($data_access, $ids) = @_;

		my @clients;
		for my $id (@$ids) {
			my $client_id = $data_access->get_client_id_by_invisalign_id($id);
			if (defined $client_id) {
				unless (exists $clients{$client_id}) {
					$clients{$client_id} = $data_access->get_client_data_by_id($client_id);
				}
				push(@clients, $clients{$client_id});
			}
			else {
				die "TODO: remove unexisting invisalign [$id]";
			}
		}
		return \@clients;
	}
}
