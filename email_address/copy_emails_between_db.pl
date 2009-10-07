#!/usr/bin/perl

use strict;

use lib qw( ../lib );

use DataSource::DB;

my ($db_from, $db_to) = @ARGV;

if (defined $db_to) {
	my $data_source = DataSource::DB->new();
	my $client_data_from = $data_source->get_client_data_by_db($db_from);
	my $client_data_to   = $data_source->get_client_data_by_db($db_to);
	
	my $from_emails = $client_data_from->get_all_emails();
	my $added_count = 0;
	for my $from_email (@$from_emails) {
		my $candidate_manager = CandidateManager->new(
			{
				'by_pat_resp_with_phone' => 1,
				'by_pat_resp' => 2,
				'by_resp' => 3,
			}
		);
		if ($from_email->{'RId'}) {
			my $from_responsible = $client_data_from->get_responsible_by_id(
				$from_email->{'RId'},
			);
			my $to_responsibles = $client_data_to->get_responsible_ids_by_name( 
				$from_responsible->{'FName'}, 
				$from_responsible->{'LName'}, 
			);
			for my $to_responsible (@$to_responsibles) {
#				print $from_email->{Email}." - ".$from_responsible->{'RId'}." - ".$to_responsible->{'RId'}."\n";
				if ($from_email->{'PId'}) {
					my $from_patient = $client_data_from->get_patient_by_id(
						$from_email->{'PId'},
					);
					my $to_patients_ids = $client_data_to->get_patient_ids_by_responsible(
						$to_responsible->{'RId'},
					);
					my $to_patients = $client_data_to->get_patients_by_name_and_ids( 
						$from_patient->{'FName'}, 
						$from_patient->{'LName'},
						$to_patients_ids,
					);
					for my $to_patient (@$to_patients) {
						$candidate_manager->add_candidate(
							'by_pat_resp',
							{
								'patient' => $to_patient,
								'responsible' => $to_responsible,
							},
						);
					}
					if ($from_patient->{'Phone'}) {
						my $to_patients_with_phone = $client_data_to->get_patients_by_name_and_phone_and_ids( 
							$from_patient->{'FName'}, 
							$from_patient->{'LName'},
							$from_patient->{'Phone'},
							$to_patients_ids,
						);
						for my $to_patient (@$to_patients_with_phone) {
							$candidate_manager->add_candidate(
								'by_pat_resp_with_phone',
								{
									'patient' => $to_patient,
									'responsible' => $to_responsible,
								},
							);
						}
					}
				}
				else {
					$candidate_manager->add_candidate(
						'by_resp',
						{
							'patient' => undef,
							'responsible' => $to_responsible,
						},
					);
				}
			}
		}
		my $candidate = $candidate_manager->get_single_candidate();
		if (defined $candidate) {
			my $email_exists = $client_data_to->email_exists_by_rid(
				$from_email->{'Email'},
				$candidate->{'responsible'}{'RId'},
			);
			if ($email_exists) {
				printf(
					"SKIP: email [%s] is already added\n", 
					$from_email->{'Email'}, 
				);
			}
			else {
				printf(
					"ADD: %s\n", 
					$from_email->{'Email'}, 
				);
				$client_data_to->add_email(
					(defined $candidate->{'patient'} ? $candidate->{'patient'}{'PId'} : 0 ),
					$candidate->{'responsible'}{'RId'},
					$from_email->{'Email'},
					$from_email->{'BelongsTo'},
					$from_email->{'Name'},
					$from_email->{'Status'},
					$from_email->{'Source'},
				);
				$added_count++;
			}
		}
		else {
			printf(
				"SKIP: %s - %s\n", 
				$from_email->{'Email'}, 
				$candidate_manager->candidates_count_str(),
			);
		}
	}
    for my $sql (@{ $data_source->get_statements() }) {
        print "$sql;\n";
    }
	printf("[%d] emails added\n", $added_count);
}
else {
	print("Usage: $0 <db_from> <db_to>\n");
	exit(1);
}

package CandidateManager;

sub new {
	my ($class, $priorities) = @_;
	
	return bless {
		'candidates' => {},
		'priorities' => $priorities,
	}, $class;
}

sub add_candidate {
	my ($self, $priority, $params) = @_;
	
	unless (exists $self->{'priorities'}{$priority}) {
		die "unknow priority [$priority]";
	}
	
	push(
		@{ $self->{'candidates'}{$priority} },
		$params,	
	);
}

sub candidates_count_str {
	my ($self) = @_;
	
	my $priorities = $self->_get_candidate_priorities();
	if (@$priorities) {
		return join(', ', map {"$_ -> ".@{ $self->{'candidates'}{$_} }.' variants' } @$priorities);
	}
	else {
		return 'no variants';
	}
}

sub _get_candidate_priorities {
	my ($self) = @_;
	
	return [ 
		sort { $self->{'priorities'}{$a} <=> $self->{'priorities'}{$b} } 
		keys %{ $self->{'candidates'} } 
	];	
}

sub get_single_candidate {
	my ($self) = @_;
	
	my @priorities = 
		grep {1 == @{ $self->{'candidates'}{$_} }} 
		@{ $self->_get_candidate_priorities() };
	if (@priorities) {
		my $min_priority = $priorities[0];
		return $self->{'candidates'}{$min_priority}[0];		
	}
	return undef;
}