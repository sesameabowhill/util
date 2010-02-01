## $Id$
package Report::CancelledMembers;

use strict;
use warnings;

use DateUtils;

sub get_columns {
	my ($class) = @_;

	return [ 'type', 'username', 'patient volume', '# of doctors', 'last month pats seen', 'last month pats regitered' ];
}

sub generate_report {
    my ($class, $client_data) = @_;

    my $cancellation_date = $client_data->get_profile_value('CancellationDate');
    if (defined $cancellation_date) {
    	my $volume_start_date = DateUtils->parse_mysql_date($cancellation_date);
    	$volume_start_date->add_days(-60);

    	my $last_month_start_date = DateUtils->parse_mysql_date($cancellation_date);
    	$last_month_start_date->add_days(-30);

    	printf(
    		"client [%s]: cancelled at [%s]\n",
    		$client_data->get_username(),
    		$cancellation_date,
    	);
		my ($month_all_pats, $month_registered_pats) = $class->get_last_month_patients_statistics(
			$client_data,
			$last_month_start_date->as_mysql_date(),
			$cancellation_date,
		);
	    return [
	    	{
	    		'type'            => $client_data->get_full_type(),
	    		'username'        => $client_data->get_username(),
	    		'patient volume'  => $class->get_patient_volume(
	    			$client_data,
	    			$volume_start_date->as_mysql_date(),
	    			$cancellation_date,
	    		),
	    		'# of doctors'    => $class->get_number_of_doctors($client_data),
	    		'last month pats seen' => $month_all_pats,
	    		'last month pats regitered' => $month_registered_pats,
	    	}
	    ];
    }
    else {
    	printf(
    		"WARN [%s]: [CancellationDate] is not set\n",
    		$client_data->get_username(),
    	);
    	return [];
    }
}

sub get_patient_volume {
    my ($class, $client_data, $start_date, $end_date) = @_;

    my $appointments_per_group = $client_data->get_number_of_appointments_per_date();
    my @filtered_appointmets = (
    	grep {
    		$_->{'Count'} > 2 && $_->{'Date'} gt $start_date && $_->{'Date'} le $end_date
    	}
    	@$appointments_per_group
    );
    if (@filtered_appointmets) {
		my $app_count = 0;
		for my $app (@filtered_appointmets) {
			$app_count += $app->{'Count'};
		}
		return sprintf('%.1f', $app_count/@filtered_appointmets);
    }
    else {
    	return 0;
    }
}

sub get_number_of_doctors {
    my ($class, $client_data) = @_;

    my $sales_resources = $client_data->get_sales_resources();
    if (defined $sales_resources) {
    	return $sales_resources->{'doctors_count'};
    }
    else {
    	return '';
    }
}

sub get_last_month_patients_statistics {
    my ($class, $client_data, $start_date, $end_date) = @_;

	my $last_appointments = $client_data->get_appointments_by_date_interval($start_date, $end_date);
	my %patient_ids = map {$_->{'PId'} => 1} @$last_appointments;
	my @pats_with_emails = grep { $client_data->count_emails_by_pid($_) } (keys %patient_ids);
	return (
		scalar keys %patient_ids,
		scalar @pats_with_emails,
	);
}

1;