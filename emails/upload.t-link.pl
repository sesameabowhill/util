#!/usr/bin/perl

use strict;
use warnings;


use DB::Doctor;


use constant FILE_PATIENTS_MAILS     => 'mails.patients.txt';
use constant FILE_RESPONSIBLES_MAILS => 'mails.responsibles.txt';

use constant R_ORIENTED => 'resp_oriented';
use constant P_ORIENTED => 'pat_oriented';

# only for patient oriented
# "1" - add mail to responsible if he has only one patient (mail added with pid of this patient)
# "0" - add mail to responsible if he has any patients (mail added to random patient)
use constant ADD_MAIL2RESP_IF_ONE_PATIENT => 1;


################################################################################
# main code
################################################################################
usage() if (scalar(@ARGV) < 2);

my ($client_db_name, $client_type, $fn_responsibles, $fn_patients) = @ARGV;

usage() unless (defined($client_type) && (($client_type eq P_ORIENTED) || ($client_type eq R_ORIENTED)));

$fn_responsibles ||= FILE_RESPONSIBLES_MAILS;
$fn_patients     ||= FILE_PATIENTS_MAILS;

my $doctor = DB::Doctor->new( {db_name => $client_db_name} );
main();


#################################################################################
# subroutines
################################################################################
sub usage {
	print STDERR "usage: $0 client_db_name {".R_ORIENTED.'|'.P_ORIENTED."} [file_name_responsibles [file_name_patients]]\n";
	exit(1);
}


sub main {
	my $responsibles = load_mails($fn_responsibles);
	my $patients     = load_mails($fn_patients);

	my $pats_stat_expected = get_statistics($patients);
	my $resp_stat_expected = get_statistics($responsibles);

	#remove_doubles($patients, $responsibles);
	process_responsibles($responsibles);
	process_patients($patients);

	my $pats_stat_got = get_statistics($patients);
	my $resp_stat_got = get_statistics($responsibles);

	print
		"\npatients:\n".
		"\texpected: ".$pats_stat_expected->{mails_count}." mails for ".$pats_stat_expected->{count}." patients\n".
		"\tuploaded: ".$pats_stat_got->{mails_count}.     " mails for ".$pats_stat_got->{modified_persons}." patients\n".
        "\tfound in dr. database: ".$pats_stat_got->{count}. " patients\n".
		"\nresponsibles:\n".
		"\texpected: ".$resp_stat_expected->{mails_count}." mails for ".$resp_stat_expected->{count}." responsibles\n".
		"\tuploaded: ".$resp_stat_got->{mails_count}.     " mails for ".$resp_stat_got->{modified_persons}." responsibles\n".
        "\tfound in dr. database: ".$resp_stat_got->{count}. " responsibles\n"
	;
}


sub get_today {
	my ($day, $month, $year) = (localtime())[3,4,5];
	$month++;
	$year += 1900;
	return join('-', $year, $month, $day);
}


sub get_names {
	my ($fullname) = @_;

	my @parts = split(/\s+/, $fullname);

	my @result = ();

	if (scalar(@parts) == 2) {
		my $fname = $parts[0];
		my $lname = $parts[1];
		push(@result, [$fname, $lname]);
	}
	elsif (scalar(@parts) > 2) {
		for(my $i=0; $i<scalar(@parts)-1; $i++) {
			my $fname = join(' ', @parts[0..$i]);
			my $lname = join(' ', @parts[$i+1..$#parts]);
			push(@result, [$fname, $lname]);
		}
	}

	return \@result;
}

sub remove_doubles {
	my ($pats, $resp) = @_;

	for my $name (sort keys %$pats) {
		if (exists($resp->{$name})) {
			patient_not_used(
				{
					name   => $name,
					emails => $pats->{$name},
					reason => 'duplicate with responsibles',
				},
			);
			delete($pats->{$name});

			responsible_not_used(
				{
					name   => $name,
					emails  => $resp->{$name},
					reason => 'duplicate with patients',
				},
			);
			delete($resp->{$name});
		}
	}
}


################################################################################
# patients
################################################################################
sub process_patients {
	my ($pats) = @_;

	for my $name (keys %$pats) {
		my $patients_in_db = [];
		my $names = get_names($name);
		for my $name_pair (@$names) {
			$patients_in_db = get_patient_list_by_name(
				$name_pair->[0],
				$name_pair->[1],
			);
			last if (scalar(@$patients_in_db)); # patient found
		}
		my $same_pats_in_db = scalar(@$patients_in_db);

		if ($same_pats_in_db == 0) {
			patient_not_used(
				{
					name   => $name,
					emails => $pats->{$name},
					reason => 'did\'t found in db',
				},
			);
			delete($pats->{$name});
		}
		elsif ($same_pats_in_db > 1) {
			patient_not_used(
				{
					name   => $name,
					emails => $pats->{$name},
					reason => $same_pats_in_db.' patients with the same name in db',
				},
			);
			delete($pats->{$name});
		}
		else {
			my $pid = $patients_in_db->[0]->{PId};
			my $used_mails = process_patient($pid, $name, $pats->{$name});
			unless (scalar(@$used_mails)) {
				patient_not_used(
					{
						name   => $name,
						emails => $pats->{$name},
						reason => 'all mails have already existed in db',
					},
				);
			}
			$pats->{$name} = $used_mails;
		}
	}
}


sub process_patient {
	my ($pid, $name, $mails) = @_;

	my $responsibles = $doctor->get_responsibles_for_patient($pid);

	if (scalar(@$responsibles) < 1) {
		if ($client_type eq R_ORIENTED) {
			for my $mail (@$mails) {
				patient_not_used(
					{
						name   => $name,
						emails  => [ $mail ],
						reason => 'no responsibles',
					},
				);
			}
			return undef;
		}
		else {
			$responsibles = [{RId => 0}];
		}
	}

	my @used_mails = ();
	for my $mail (@$mails) {
		for my $resp (@$responsibles) {
			my $rpid = $resp->{RId};
			my $mails_in_db = get_patient_emails($pid);

			unless (exists($mails_in_db->{$mail})) {
				$doctor->add_email_to_patient(
					{
						name       => $name,
						resp_id    => $rpid,
						pat_id     => $pid,
						email      => $mail,
						belongs_to => 0,
						date       => get_today(),
						source     => 'other',
					},
					{
						resp_id => $rpid,
						pat_id  => $pid,
					},
					0,
				);

				push(@used_mails, $mail);
			}
		}
	}

	return \@used_mails;
}


sub get_patient_list_by_name {
	my ($fname, $lname) = @_;

	my $sql_query = 'SELECT PId FROM patients WHERE (FName = ?) AND (LName = ?)';

	my $sth = $doctor->{db_handle}->prepare($sql_query);
	$sth->execute($fname, $lname);

	return $sth->fetchall_arrayref({});
}


sub get_patient_emails {
	my ($pid) = @_;

	my $maildata_in_db = $doctor->get_patient_email($pid);
	my %mails_in_db = map { lc($_->{Email}) => 1 } @$maildata_in_db;

	return \%mails_in_db;
}


################################################################################
# responsibles
################################################################################
sub process_responsibles {
	my ($resp) = @_;

	for my $name (keys %$resp) {
		my $responsibles_in_db = [];
		my $names = get_names($name);
		for my $name_pair (@$names) {
			$responsibles_in_db = get_responsible_list_by_name(
				$name_pair->[0],
				$name_pair->[1],
			);
			last if (scalar(@$responsibles_in_db)); # responsible found
		}
		my $same_resp_in_db = scalar(@$responsibles_in_db);

		if ($same_resp_in_db == 0) {
			responsible_not_used(
				{
					name   => $name,
					emails => $resp->{$name},
					reason => 'did\'t found in db',
				},
			);
			delete($resp->{$name});
		}
		elsif ($same_resp_in_db > 1) {
			responsible_not_used(
				{
					name   => $name,
					emails => $resp->{$name},
					reason => $same_resp_in_db.' responsibles with the same name in db',
				},
			);
			delete($resp->{$name});
		}
		else {
			my $rpid = $responsibles_in_db->[0]->{RId};
			my $used_mails = process_responsible($rpid, $name, $resp->{$name});
			unless (ref $used_mails) {
				responsible_not_used(
					{
						name   => $name,
						emails => $resp->{$name},
						reason => $used_mails,
					},
				);
				$used_mails = [];
			}
			elsif (!scalar(@$used_mails)) {
				responsible_not_used(
					{
						name   => $name,
						emails => $resp->{$name},
						reason => 'all mails have already existed in db',
					},
				);
			}
			$resp->{$name} = $used_mails;
		}
	}
}


sub process_responsible {
	my ($rpid, $name, $mails) = @_;

	my @used_mails = ();

	my $pid;
	if ($client_type eq P_ORIENTED) {
		my $patients = get_patients4responsible($rpid);

		if ((ADD_MAIL2RESP_IF_ONE_PATIENT && (scalar(@$patients) == 1)) ||
			(!ADD_MAIL2RESP_IF_ONE_PATIENT && scalar(@$patients))) {
			$pid = $patients->[0];
		}
		else {
			return "ADD_MAIL2RESP_IF_ONE_PATIENT=".ADD_MAIL2RESP_IF_ONE_PATIENT.
				" and count(patients)=".scalar(@$patients);
		}
	}
	else {
		$pid = 0;
	}

	for my $mail (@$mails) {
		my $mails_in_db = get_responsible_emails($rpid);

		unless (exists($mails_in_db->{$mail})) {
			$doctor->add_email_to_patient(
				{
					name       => $name,
					resp_id    => $rpid,
					pat_id     => $pid,
					email      => $mail,
					belongs_to => 1,
					date       => get_today(),
					source     => 'other',
				},
				{
					resp_id => $rpid,
					pat_id  => $pid,
				},
				0,
			);

			push(@used_mails, $mail);
		}
	}

	return \@used_mails;
}


sub get_responsible_list_by_name {
	my ($fname, $lname) = @_;

	my $sql_query = 'SELECT RId FROM responsibles WHERE (FName = ?) AND (LName = ?)';

	my $sth = $doctor->{db_handle}->prepare($sql_query);
	$sth->execute($fname, $lname);

	return $sth->fetchall_arrayref({});
}


sub get_responsible_emails {
	my ($rpid) = @_;

	my $sql_query = 'SELECT ml_email FROM maillist WHERE (ml_resp_id = ?)';

	my $sth = $doctor->{db_handle}->prepare($sql_query);
	$sth->execute($rpid);

	my $maildata_in_db = $sth->fetchall_arrayref({});
	my %mails_in_db = map { lc($_->{ml_email}) => 1 } @$maildata_in_db;

	return \%mails_in_db;
}


sub get_patients4responsible {
	my ($rpid) = @_;

	my $sql_query = 'SELECT PId FROM prlinks WHERE RId=?';

	my $result = $doctor->{db_handle}->selectcol_arrayref(
		$sql_query,
		undef,
		$rpid
	);

	return $result;
}


################################################################################
# output and statistics
################################################################################
sub patient_not_used {
	my ($pairs) = @_;

	$pairs->{type} = 'patient';
	item_not_used($pairs);
}


sub responsible_not_used {
	my ($pairs) = @_;

	$pairs->{type} = 'responsible';
	item_not_used($pairs);
}


sub item_not_used {
	my ($pairs) = @_;

	if (exists($pairs->{emails})) {
		$pairs->{emails} = join(', ', @{$pairs->{emails}});
	}

	print $pairs->{type}." not used\n";
	delete($pairs->{type});

	for my $key (sort keys %$pairs) {
		print "\t".$key.": ".$pairs->{$key}."\n";
	}

	print "\n";
}


sub get_statistics {
	my ($data) = @_;
    my $modified_persons = 0;

    my $count = scalar(keys %$data);

	my $mails_count = 0;
	for my $emails (values %$data) {
        if (scalar(@$emails)) {
            $mails_count += scalar(@$emails);
            $modified_persons++;
        }
	}

	return {
		count       => $count,
		mails_count => $mails_count,
        modified_persons => $modified_persons,
	};
}


################################################################################
# files
################################################################################
sub load_mails {
	my ($fn) = @_;

	my %lines =();
	my %data = ();

	open(RESP, "<", $fn) or die $!;
	for my $line (<RESP>) {
		next if ($line =~ m/^DO NOT USE /);

		$line =~ s/[\r\n]+$//;

		unless (exists($lines{$line})) {
			$lines{$line} = 1;

			if ($line =~ /^(.+?\S)\s+(\S+)$/) {
				my $name = $1;
				my $mail = $2;
				$data{$name} = [] unless (exists($data{$name}));
				push(@{$data{$name}}, lc($mail));
			}
			else {
				print "Illegal line \"$line\" in file \"$fn\"\n";
			}
		}
	}
	close(RESP);

	return \%data;
}