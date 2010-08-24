## $Id: Base.pm 2085 2010-06-03 21:57:43Z ivan $
package Migrate::PatientPasswords;

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

	if ($client_data_4->get_full_type() eq 'ortho_resp') {
		my $remap_tables = $client_data_4->get_all_remap_tables();
		my %table_id = map {$_->{'name'} => $_->{'id'}} @{ $remap_tables };
		my $sesame_accounts = $client_data_4->get_all_sesame_accounts();
		my $processed_count = 0;
		for my $sesame_account (@$sesame_accounts) {
			my $responsible_4 = $client_data_4->get_responsible_by_id( $sesame_account->{'RId'} );
			my $orig_id = $client_data_4->get_reverse_remap(
				$table_id{'responsibles'},
				$sesame_account->{'RId'},
			);
			if (defined $orig_id) {
				my $responsible_5 = $client_data_5->get_responsibles_by_name_and_pms_id(
					$responsible_4->{'FName'},
					$responsible_4->{'LName'},
					$orig_id,
				);
				if (@$responsible_5) {
					$client_data_5->set_visitor_password_by_id($sesame_account->{'Password'}, $responsible_5->[0]{'RId'});
					$self->{'logger'}->register_category("password is changed");
					if ($processed_count % 100 == 0) {
						printf(
							"CLIENT [%s]: (%d/%d) change password\n",
							$client_data_5->get_username(),
							$processed_count,
							scalar @$sesame_accounts,
						);
					}
				}
				else {
					$self->{'logger'}->register_category("failed to find responsible in 5.0");
				}
			}
			else {
				$self->{'logger'}->register_category("failed to find pms id in 4.6");
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

## resp
#
#4 RULE: visitor <= sesame_accounts (ortho_resp1)
#FIELD: const - [blocked_source]
#FIELD: const - [privacy]
#FIELD: copy - [password] <= [pswd]
#FIELD: get_status - [blocked]
#METHOD: update
#EACH: SELECT id FROM visitor WHERE id = ?said?
#UPDATE: UPDATE visitor SET blocked = ?, password = ?, privacy = ?, blocked_source = ? WHERE id = ?
#
#5 RULE: visitor <= sesame_accounts (ortho_resp2)
#FIELD: const - [blocked_source]
#FIELD: const - [privacy]
#FIELD: copy - [password] <= [pswd]
#FIELD: get_status - [blocked]
#METHOD: update multi
#EACH: SELECT patient_id AS id FROM visitor, responsible_patient WHERE visitor.id = responsible_patient.responsible_id AND responsible_id = ?said? AND visitor.type = 'responsible'
#UPDATE: UPDATE visitor SET blocked = ?, password = ?, privacy = ?, blocked_source = ? WHERE patient_id AS id = ?


1;