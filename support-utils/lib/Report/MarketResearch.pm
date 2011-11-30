## $Id$
package Report::MarketResearch;

use strict;
use warnings;

use DateUtils;

use Report::CancelledMembers;

sub get_columns {
	my ($class) = @_;

	return [
		'type',
		'username',
		'patient volume',
		'# of doctors',
		'install date',
		'# of voice calls',
		'date of last newsletter',
		'# of invisalign pats',
		'# of SI images',
		'city',
		'zip',
	];
}

sub generate_report {
	my ($class, $client_data) = @_;

	my $now = DateUtils->now();
	my $volume_start_date = $now->clone();
	$volume_start_date->add_days(-60);

	my $sales_resources = $client_data->get_sales_resources();
	my $voice_calls = $client_data->get_all_voice_sent_calls();
	my $invisalign_patients = $client_data->get_all_invisalign_patients();
	#my $si_images = $client_data->get_all_si_images();

	return [
		{
			'type'            => $client_data->get_full_type(),
			'username'        => $client_data->get_username(),
			'patient volume'  => Report::CancelledMembers->get_patient_volume(
				$client_data,
				$volume_start_date->as_mysql_date(),
				$now->as_mysql_date(),
			),
			'# of doctors' => $sales_resources->{'doctors_count'},
			'install date' => $client_data->get_start_date(),
			'# of voice calls' => scalar @$voice_calls,
			'date of last newsletter' => $class->get_last_ppn_date($client_data),
			'# of invisalign pats' => scalar @$invisalign_patients,
			'# of SI images' => $client_data->count_all_si_images(),
			'city' => $sales_resources->{'city'},
			'zip' => $sales_resources->{'zip_code'},
		}
	];
}

sub get_last_ppn_date {
	my ($class, $client_data) = @_;

	my $all_ppn = $client_data->get_all_ppn_emails();
	if (@$all_ppn) {
		@$all_ppn = sort {$b->{'dt'} cmp $a->{'dt'}} @$all_ppn;
		return $all_ppn->[0]{'dt'};
	}
	else {
		return '';
	}
}

1;