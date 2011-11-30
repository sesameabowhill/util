## $Id$
package Repair::ResurectClincheck;

use strict;
use warnings;

use base 'Repair::RepairClincheck';

sub new {
	my $class = shift;

	my $self = $class->SUPER::new(@_);
	$self->{'commands'} = [];
	return $self;
}

sub save_commands {
	my ($self, $fn) = @_;

	open(my $f, ">", $fn) or die "can't write [$fn]: $!";
	print $f "## $fn\n";
	for my $cmd (@{ $self->{'commands'} }) {
		print $f "$cmd\n";
	}
	close($f);
}

sub add_command {
	my ($self, $cmd) = @_;

	push(@{ $self->{'commands'} }, $cmd);
}

sub repair_clincheck_for_single_client {
	my ($self, $data_access, $case, $icp_client_id, $inv_client_id, $client_data) = @_;

}

sub repair_clincheck_for_two_clients {
	my ($self, $data_access, $case, $icp_client_id, $inv_client_id, $client_data_by_icp, $client_data_by_inv) = @_;

}

sub repair_clincheck_with_one_icp_client {
	my ($self, $data_access, $case, $icp_client_id, $client_data) = @_;

	my $expected_file = $client_data->file_path_for_invisalign_comment(
		$icp_client_id,
		$case->{'case_number'},
	);
	my $todo = "";
	unless (-f $expected_file) {
		my $to_folder = $client_data->file_path_for_clinchecks($icp_client_id);
		if (-d $to_folder) {
			$todo = " (copy files)";
		}
		else {
			$todo = " (mkdir, copy files)";
			$self->add_command('mkdir '.$to_folder);
			#mkdir($to_folder) or die "can't mkdir [$to_folder]: $!";
		}
		$self->add_command('cp -v '.$case->{'file_mask'}.' '.$to_folder);
	}
	printf(
		"case [%s]: resurect\n",
		$case->{'case_number'},
		$case->{'file'},
		$expected_file,
	);

	my $processing_patient = $client_data->get_invisalign_processing_patient($case->{'case_number'});
	$client_data->add_invisaling_patient(
		$case->{'case_number'},
		$icp_client_id,
		{
			'fname' => $processing_patient->{'fname'},
			'lname' => $processing_patient->{'lname'},
			'post_date' => $case->{'file_mtime'},
			'start_date' => $processing_patient->{'post_date'} || $case->{'file_mtime'},
			'transfer_date' => $case->{'date'} || $processing_patient->{'post_date'},
			'retire_date' => $case->{'file_mtime'},
			'stages' => ($case->{'stages'} || 0),
		},
	);
	#my $todo = $self->repair_processed_clincheck($client_data, $case->{'case_number'}, \@todo);
	$self->{'logger'}->register_category("clincheck is resurected$todo");
}

sub repair_clincheck_with_one_inv_client {
	my ($self, $data_access, $case, $inv_client_id, $client_data) = @_;

}

1;