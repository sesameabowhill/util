## $Id$
package ClientData::DB;

use strict;

use DBI;

use Sesame::Unified::Client;

sub new {
	my ($class, $data_source, $db_name) = @_;

	my $client_ref = Sesame::Unified::Client->new('db_name', $db_name);
	my $client_type = $client_ref->get_client_type();

	my $dbi = $data_source->get_connection( $db_name );
	if ($client_type eq 'dental') {
		$class = 'ClientData::DB::Dental';
		require ClientData::DB::Dental;
	}
	else {
		my $context = $dbi->selectrow_array(<<'SQL', undef ,$db_name);
SELECT s.dbs_context
FROM sesameweb.clients cl
LEFT JOIN sesameweb.udbf_software s ON (s.dbs_id=cl.cl_pms)
WHERE cl.cl_mysql=?
SQL
		if ($context eq 'pat') {
			$class = 'ClientData::DB::OrthoPat';
			require ClientData::DB::OrthoPat;
		}
		elsif ($context eq 'resp') {
			$class = 'ClientData::DB::OrthoResp';
			require ClientData::DB::OrthoResp;
		}
		else {
			die "unknown Ortho context [$context] for [$db_name]";
		}
	}

	my $self = bless {
		'dbh' => $dbi,
		'data_source' => $data_source,
		'strict_search' => 1,
		'client_ref' => $client_ref,
		'cached_data' => {},
	}, $class;

	return $self;
}

sub get_db_name {
	my ($self) = @_;

	return $self->{'client_ref'}->get_db_name();
}

sub set_strict_level {
	my ($self, $level) = @_;

	$self->{'strict_search'} = $level;
}

sub _search_by_name {
	my ($self, $fields, $table, $fname, $lname, $where) = @_;

	if (defined $where) {
		$where = " AND $where";
	}
	my $result;
	if (defined $lname) {
		$result = $self->{'dbh'}->selectall_arrayref(
			"SELECT $fields FROM $table WHERE FName=? AND LName=?$where",
			{ 'Slice' => {} },
			$fname, $lname
		);
	}
	else {
		$result = $self->{'dbh'}->selectall_arrayref(
			"SELECT $fields FROM $table WHERE CONCAT(FName, ' ', LName)=?$where",
			{ 'Slice' => {} },
			$fname
		);
	}
	unless ($self->{'strict_search'}) {
		unless (@$result) {
			if (defined $lname) {
				$result = $self->{'dbh'}->selectall_arrayref(
					"SELECT $fields FROM $table WHERE CONCAT(FName, ' ', LName) LIKE ?$where",
					{ 'Slice' => {} },
					$self->_string_to_like("$fname $lname"),
				);
			}
			else {
				$result = $self->{'dbh'}->selectall_arrayref(
					"SELECT $fields FROM $table WHERE ? LIKE CONCAT('%', FName, ' ', LName,'%')$where",
					{ 'Slice' => {} },
					$fname,
				);
			}
		}
	}
	return $result;
}

sub _string_to_like {
	my ($self, $str) = @_;

	$str =~ s/\b/ /g;
	$str =~ s/\s+/%/g;
	return $str;
}

sub add_colleague {
	my ($self, $fname, $lname, $email, $password) = @_;

	my $new_id = 1 + $self->{'dbh'}->selectrow_array("SELECT max(id) FROM referring_contacts");

	my $insert_cmd = "INSERT INTO referring_contacts (id, fname, lname, practice_name, email, speciality) VALUES (".$self->{'dbh'}->quote($new_id).", ".$self->{'dbh'}->quote($fname).", ".$self->{'dbh'}->quote($lname).", NULL, ".$self->{'dbh'}->quote($email).", NULL)";
	$self->{'dbh'}->do($insert_cmd);
	$self->{'data_source'}->add_statement($insert_cmd);

	my $si_insert_cmd = "INSERT INTO SI_Doctor (FName, LName, Status, Password, Deleted, WelcomeSent, PrivacyAccepted, ref_contact_id, AutoNotify) VALUES (NULL, NULL, 1, ".$self->{'dbh'}->quote($password).", 0, 0, 0, ".$self->{'dbh'}->quote($new_id).", 0)";
	$self->{'dbh'}->do($si_insert_cmd);
	$self->{'data_source'}->add_statement($si_insert_cmd);

	my $ref_insert_cmd = "INSERT INTO referrings (ref_fname, ref_lname, ref_email, ref_contact_id) VALUES (".$self->{'dbh'}->quote($fname).", ".$self->{'dbh'}->quote($lname).", ".$self->{'dbh'}->quote($email).", ".$self->{'dbh'}->quote($new_id).")";
	$self->{'dbh'}->do($ref_insert_cmd);
	$self->{'data_source'}->add_statement($ref_insert_cmd);
}

sub email_exists_by_colleague {
	my ($self, $email) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
		"SELECT count(*) FROM referring_contacts WHERE email=?",
		undef,
		$email,
	);
}

sub is_active {
	my ($self) = @_;

	return $self->{'client_ref'}->is_active();
}

sub get_unsubscribed_emails {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT Email, Type FROM unsubscribe",
		{ 'Slice' => {} },
	);
}

sub get_email_reminder_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT id, is_enabled, type, subject, body, response_options, design_id, image_guid, image_title FROM email_messaging.reminder_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_ref'}->get_id(),
	);
}

sub get_ccp_id {
	my ($self) = @_;

	return $self->get_cached_data(
		'_ccp_id',
		sub {
			my ($type, $id) = ($self->{'client_ref'}->get_id() =~ m/^(\w)(\d+)$/);

			return scalar $self->{'dbh'}->selectrow_array(
				"SELECT CID FROM opse.clients WHERE Category=? AND OuterId=?",
				undef,
				($type eq 'd' ? 'Dental' : 'Ortho'),
				$id,
			);
		}
	);
}

sub get_voice_id {
	my ($self) = @_;

	return $self->get_cached_data(
		'_voice_id',
		sub {
			return scalar $self->{'dbh'}->selectrow_array(
				"SELECT id FROM voice.Clients WHERE db_name=?",
				undef,
				$self->{'client_ref'}->get_db_name(),
			);
		}
	);
}

sub get_all_voice_queued_calls {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, cid, rec_id, rec_phone, xml_request, message_type, time2send, unique_key, event_datetime FROM voice.Queue WHERE cid=?",
		{ 'Slice' => {} },
		$self->get_voice_id(),
    );
}

sub set_voice_queued_call_time {
	my ($self, $call_id, $time_to_sent, $xml_request) = @_;

	$self->{'dbh'}->do(
		"UPDATE voice.Queue SET time2send=?, xml_request=? WHERE id=?",
		undef,
		$time_to_sent,
		$xml_request,
		$call_id,
	);
}

sub get_complete_cc_payments {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Time AS DateTime, Provider, FName, LName, Email, Comment, Amount, PaymentType AS Type FROM opse.payment_log WHERE CID=? AND if(Provider='PRI', TResult='OK', Provider='Malse') ORDER BY Time",
		{ 'Slice' => {} },
		$self->get_ccp_id(),
    );
}

sub get_sent_emails_by_pid_type {
	my ($self, $pid, $type) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, sml_resp_id AS RId, sml_pat_id AS PId, sml_email as Email, sml_date AS DateTime, sml_belongsto, sml_name, sml_mail_type, sml_mail_id, sml_body, sml_body_hash FROM sent_mail_log WHERE sml_mail_type=? AND sml_pat_id=? ORDER BY sml_date",
		{ 'Slice' => {} },
        $type,
        $pid,
    );
}

sub count_sent_emails_by_type {
	my ($self, $type) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM sent_mail_log WHERE sml_mail_type=?",
        undef,
		$type,
    );

}

sub get_cached_data {
	my ($self, $key, $generate_cache_sub) = @_;

	unless (exists $self->{'cached_data'}{$key}) {
		$self->{'cached_data'}{$key} = $generate_cache_sub->();
	}
	return $self->{'cached_data'}{$key};
}

1;