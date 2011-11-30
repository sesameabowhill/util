## $Id: Base.pm 2085 2010-06-03 21:57:43Z ivan $
package Migrate::PatientPhones;

use strict;
use warnings;

sub new {
	my ($class, $logger) = @_;

	return bless {
		'logger' => $logger,
	}, $class;
}

sub migrate {
	my ($self, $client_data_5, $client_data_4) = @_;

	if ($client_data_4->get_full_type() =~ m'^ortho') {
		my $remap_tables = $client_data_4->get_all_remap_tables();
		my %table_id = map {$_->{'name'} => $_->{'id'}} @{ $remap_tables };

		my $patient_phones = $client_data_4->get_all_patient_phones();
		my $processed_count = 0;
		for my $patient_phone (@$patient_phones) {
			my $valid_phone_number = get_valid_phone_number( $patient_phone->{'number'} );
			if (defined $valid_phone_number) {
				my $patient_4 = $client_data_4->get_patient_by_id( $patient_phone->{'PId'} );
				my $orig_id = $client_data_4->get_reverse_remap(
					$table_id{'patients'},
					$patient_phone->{'PId'},
				);
				if ($client_data_5->phone_is_used($valid_phone_number)) {
					if ($patient_phone->{'sms_active'}) {
						my $patient_5 = $client_data_5->get_patients_by_name_and_pms_id(
							$patient_4->{'FName'},
							$patient_4->{'LName'},
							$orig_id,
						);
						if (@$patient_5) {
							$client_data_5->set_sms_active_for_phone_number(
								$patient_5->[0]{'PId'},
								$valid_phone_number,
								$patient_phone->{'sms_active'},
							);
							$self->{'logger'}->register_category("activate phone for sms");
							printf(
								"CLIENT [%s]: set sms active for phone [%s]\n",
								$client_data_5->get_username(),
								$valid_phone_number,
							);
						}
						else {
							$self->{'logger'}->register_category("failed to find patient in 5.0");
						}

					}
					else {
						$self->{'logger'}->register_category("phone number is allready used");
						printf(
							"CLIENT [%s]: number [%s] is already used\n",
							$client_data_5->get_username(),
							$valid_phone_number,
						);
					}
				}
				else {
					if (defined $orig_id) {
						my $patient_5 = $client_data_5->get_patients_by_name_and_pms_id(
							$patient_4->{'FName'},
							$patient_4->{'LName'},
							$orig_id,
						);
						if (@$patient_5) {
							$client_data_5->add_phone(
								$patient_5->[0]{'PId'},
								$valid_phone_number,
								$patient_phone->{'type'},
								$patient_phone->{'sms_active'},
								$patient_phone->{'voice_active'},
								$patient_phone->{'source'},
								$patient_phone->{'entry_datetime'},
							);
							$self->{'logger'}->register_category("phone added");
							printf(
								"CLIENT [%s]: add phone [%s] to patient #%d [%s, %s]\n",
								$client_data_5->get_username(),
								$valid_phone_number,
								$patient_5->[0]{'PId'},
								$patient_5->[0]{'LName'},
								$patient_5->[0]{'FName'},
							);
						}
						else {
							$self->{'logger'}->register_category("failed to find patient in 5.0");
						}
					}
					else {
						$self->{'logger'}->register_category("failed to find pms id in 4.6");
					}
				}
			}
			else {
				$self->{'logger'}->register_category("phone number is invalid");
			}
			$processed_count ++;
		}

		return 1;
	}
	else {
		printf(
			"CLIENT [%s]: type %s is not supported for this migration",
			$client_data_4->get_username(),
			$client_data_4->get_full_type(),
		);
		return 0;
	}
}

sub get_valid_phone_number {
	my ($number) = @_;

	if ($number =~ m{^\d{10}$}) {
		## add country code if it's the only missing thing
		$number = '1' . $number;
	}
	if ($number =~ m{^\d{11}$}) {
		## return only valid phones
		return $number;
	}
	else {
		return undef;
	}
}

#1 RULE: phone <= patient_phones
#FIELD: const - [sms_active]
#FIELD: const - [source]
#FIELD: const - [type]
#FIELD: const - [voice_active]
#FIELD: copy - [entry_datetime] <= [registered]
#FIELD: get_client_id - [client_id]
#FIELD: get_phone_number - [number] <= [phone, areacode, countrycode]
#FIELD: remap_value - [visitor_id]
#SKIP: if [number] == undef
#METHOD: update_or_insert
#EACH: SELECT id FROM phone WHERE visitor_id = ? AND number = ?
#UPDATE: UPDATE phone SET voice_active = ?, sms_active = ?, entry_datetime = ? WHERE id = ?
#
#2 RULE: phone <= phone_patient
#FIELD: const - [source]
#FIELD: const - [type]
#FIELD: copy - [entry_datetime] <= [registered]
#FIELD: get_client_id - [client_id]
#FIELD: get_phone_number - [number] <= [phone]
#FIELD: get_status - [sms_active] <= [active]
#FIELD: remap_value - [visitor_id]
#SKIP: if [number] == undef
#METHOD: update_or_insert
#EACH: SELECT id FROM phone WHERE visitor_id = ? AND number = ?
#UPDATE: UPDATE phone SET sms_active = ?, entry_datetime = ? WHERE id = ?



1;