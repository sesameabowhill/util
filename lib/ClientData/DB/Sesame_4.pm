## $Id$
package ClientData::DB::Sesame_4;

use strict;
use warnings;

use File::Spec;

use base qw( ClientData::DB );

our %CLIENTS_TABLE_NAME = (
	'ortho' => 'sesameweb.clients',
	'dental' => 'dentists.clients',
);

my $COMMON_CLIENT_PARAMS = 'cl_id AS id, cl_mysql AS db_name, cl_pathw AS web_folder, cl_status AS status, cl_timezone AS timezone, rule_id';
my $ORTHO_CLIENT_PARAMS  = "$COMMON_CLIENT_PARAMS, 'ortho' AS type, cl_username AS username, cl_pms AS pms_id, cl_start_date";
my $DENTAL_CLIENT_PARAMS = "$COMMON_CLIENT_PARAMS, 'dental' AS type, cl_mysql AS username, cl_db AS pms_id, cl_install AS cl_start_date";


sub new {
	my ($class, $data_source, $db_name, $dbh) = @_;

	my $self = $class->SUPER::new($data_source, $db_name);

	$self->{'dbh'} = $dbh;
	$self->{'client'} = _get_client_params($self->{'dbh'}, $db_name);
	unless (defined $self->{'client'}) {
		die "can't find client by [$db_name]";
	}
	return $self->_init_params();
}

sub new_by_id {
	my ($class, $data_source, $id, $dbh) = @_;

	my $params = _get_client_params_by_id($dbh, $id);
	unless (defined $params) {
		die "can't find client by id [$id]";
	}

	my $self = $class->SUPER::new($data_source, $params->{'db_name'});
	$self->{'dbh'} = $dbh;
	$self->{'client'} = $params;
	return $self->_init_params();
}

sub _init_params {
	my ($self) = @_;

	my $class;

	my $client_type = $self->{'client'}{'type'};
	if ($client_type eq 'dental') {
		$class = 'ClientData::DB::Dental_4';
		require ClientData::DB::Dental_4;
	}
	else {
		my $db_name = $self->{'client'}{'db_name'};
		my $context = $self->{'dbh'}->selectrow_array(<<'SQL', undef, $db_name);
SELECT s.dbs_context
FROM sesameweb.clients cl
LEFT JOIN sesameweb.udbf_software s ON (s.dbs_id=cl.cl_pms)
WHERE cl.cl_mysql=?
SQL
		if ($context eq 'pat') {
			$class = 'ClientData::DB::OrthoPat_4';
			require ClientData::DB::OrthoPat_4;
		}
		elsif ($context eq 'resp') {
			$class = 'ClientData::DB::OrthoResp_4';
			require ClientData::DB::OrthoResp_4;
		}
		else {
			die "unknown Ortho context [$context] for [$db_name]";
		}
	}
	$self->{'db_name'} = $self->{'client'}{'db_name'};
	return bless($self, $class);
}

sub _get_client_params {
	my ($dbh, $db_name) = @_;

	my $params = $dbh->selectrow_hashref(<<SQL, undef, $db_name);
SELECT $ORTHO_CLIENT_PARAMS
FROM $CLIENTS_TABLE_NAME{'ortho'}
WHERE cl_mysql=?
SQL
	unless ($params) {
		$params = $dbh->selectrow_hashref(<<SQL, undef, $db_name);
SELECT $DENTAL_CLIENT_PARAMS
FROM $CLIENTS_TABLE_NAME{'dental'}
WHERE cl_mysql=?
SQL
		unless ($params) {
			return undef;
		}
	}
	return $params;
}

sub _get_client_params_by_id {
	my ($dbh, $id) = @_;

	if ($id =~ m/^o(\d+)$/) {
		my ($cl_id) = $1;
		return $dbh->selectrow_hashref(<<SQL, undef, $cl_id);
SELECT $ORTHO_CLIENT_PARAMS
FROM $CLIENTS_TABLE_NAME{'ortho'}
WHERE cl_id=?
SQL
	}
	elsif ($id =~ m/^d(\d+)$/) {
		my ($cl_id) = $1;
		return $dbh->selectrow_hashref(<<SQL, undef, $cl_id);
SELECT $DENTAL_CLIENT_PARAMS
FROM $CLIENTS_TABLE_NAME{'dental'}
WHERE cl_id=?
SQL
	}
	else {
		die "invalign client id [$id]";
	}
}

sub get_db_name {
	my ($self) = @_;

	return $self->{'db_name'};
}

sub get_username {
	my ($self) = @_;

	return $self->{'client'}{'username'};
}


sub is_active {
	my ($self) = @_;

	return $self->{'client'}{'status'} == 1;
}


sub _search_by_name {
	my ($self, $fields, $table, $fname, $lname, $where) = @_;

	return $self->_search_with_fields_by_name(
		$fields,
		'FName',
		'LName',
		$table,
		$fname,
		$lname,
		$where,
	);
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
		$self->_get_id(),
	);
}

sub get_ccp_id {
	my ($self) = @_;

	return $self->get_cached_data(
		'_ccp_id',
		sub {
			my ($type, $id) = ($self->_get_id() =~ m/^(\w)(\d+)$/);

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
				$self->get_db_name(),
			);
		}
	);
}

sub get_all_voice_queued_calls {
	my ($self) = @_;

	if (defined $self->get_voice_id()) {
		return $self->{'dbh'}->selectall_arrayref(
	        "SELECT id, cid, rec_id, rec_phone, xml_request, message_type, time2send, unique_key, event_datetime FROM voice.Queue WHERE cid=?",
			{ 'Slice' => {} },
			$self->get_voice_id(),
	    );
	}
	else {
		return [];
	}
}

sub get_all_voice_sent_calls {
	my ($self) = @_;

	if (defined $self->get_voice_id()) {
		return $self->{'dbh'}->selectall_arrayref(
	        "SELECT id, cid, rec_id, rec_phone, message_type, time2send, unique_key, event_datetime, sent_type, response_code, menu_code, sent_date, machine_answer FROM voice.MessageHistory WHERE cid=?",
			{ 'Slice' => {} },
			$self->get_voice_id(),
	    );
	}
	else {
		return [];
	}
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

sub get_all_si_images {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT ImageId, PatId, FileName FROM SI_Images",
		{ 'Slice' => {} },
    );
}

sub count_all_si_images {
	my ($self) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM SI_Images",
		undef,
    );
}

sub get_si_patient_by_id {
	my ($self, $pat_id) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT FName, LName, BDate FROM SI_Patients WHERE PatId=?",
		{ 'Slice' => {} },
		$pat_id,
    )->[0];
}

sub get_hhf_id {
	my ($self) = @_;

	return $self->get_cached_data(
		'_hhf_id',
		sub {
			return $self->get_profile_value('HHF->GUID');
		}
	);
}

sub get_hhf_user_id {
	my ($self) = @_;

	return $self->get_cached_data(
		'_hhf_user_id',
		sub {
			return scalar $self->{'dbh'}->selectrow_array(
		        "SELECT id FROM hhf.clients WHERE guid=?",
				{ 'Slice' => {} },
				$self->get_hhf_id(),
		    );
		}
	);
}

sub get_hhf_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT PKey, Type, SVal, IVal, RVal, DVal FROM hhf.settings WHERE cl_id=?",
		{ 'Slice' => {} },
		$self->get_hhf_user_id(),
    );
}

sub get_hhf_templates {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT body, 1 AS body_exists FROM hhf.templates WHERE cl_id=?",
		{ 'Slice' => {} },
		$self->get_hhf_user_id(),
    );
}

sub get_hhf_client_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT guid, install_date FROM hhf.clients WHERE id=?",
		{ 'Slice' => {} },
		$self->get_hhf_user_id(),
    );
}

sub get_all_hhf_forms {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, filldate, fname, lname, birthdate, note, signature, body FROM hhf.applications WHERE cl_id=?",
		{ 'Slice' => {} },
		$self->get_hhf_user_id(),
    );
}

sub get_all_srm_resources {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, container, date, path_from, type, description FROM srm.resources WHERE container=?",
		{ 'Slice' => {} },
		$self->get_db_name(),
    );
}

sub get_start_date {
	my ($self) = @_;

	return $self->{'client'}{'cl_start_date'};
}

sub _get_all_ppn_emails {
	my ($self, $table) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, letter_hash, is_send, send_to, recipient_count, dt, param, only_active_pats FROM $table WHERE cl_id=?",
		{ 'Slice' => {} },
		$self->{'client'}{'id'},
    );
}

sub file_path_for_si_image {
	my ($self, $file_name) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_WEB'},
    	'image_systems',
    	$self->get_username(),
    	'si',
    	'images',
    	$file_name,
    );
}


1;