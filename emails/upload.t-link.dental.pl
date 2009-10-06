## $Id$
use strict;
use warnings;

use Text::CSV_XS;

my @files = @ARGV;
if (@files) {
    my $start_time = time();
    my $add_email_count = 0;
    my @insert_commands;
    for my $file_name (@files) {
        if ($file_name =~ m/^(.*)\.(.*)\.(.*)$/) {
            my ($client_db, $type, $ext) = ($1, $2, $3);
            my $client_data = DBSource->new($client_db);
            printf "database source: client [%s]\n", $client_db;
            if ($type eq 'patient_emails') {
                my $patient_emails = read_csv($file_name, ['name', 'email']);
                $add_email_count += add_email_to_patients($client_data, $patient_emails);
            }
            elsif ($type eq 'responsible_emails') {
                my $responsible_emails = read_csv($file_name, ['name', 'email']);
                $add_email_count += add_email_to_responsibles($client_data, $responsible_emails);
            }
            elsif ($type eq 'colleagues') {
                my $colleagues = read_csv($file_name, ['name', 'email']);
                @$colleagues = grep {$_->{'name'} =~ m/\S/ && $_->{'email'} =~ m/\S/} @$colleagues;
                $add_email_count += add_colleagues($client_data, $colleagues);
            }
            else {
                die "unknown file type [$type]";
            }
            push(
                @insert_commands,
                @{ $client_data->get_insert_commands() },
            );
        }
        else {
            die "unknown file name [$file_name]";
        }
    }
    for my $cmd (@insert_commands) {
        print "$cmd;\n";
    }
    print "$add_email_count emails added\n";
    printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
    print <<USAGE;
Usage: $0 <file1> [files...]
File names:
    patient_emails.<drname>.csv
    responsible_emails.<drname>.csv
USAGE
    exit(1);
}

sub add_colleagues {
    my ($client_data, $colleagues) = @_;

    my $add_count = 0;
    for my $colleague (@$colleagues) {
        my $colleague_name = $colleague->{'name'};
        my $colleague_email = $colleague->{'email'};
        my $is_colleague_exists = $client_data->is_colleague_exists($colleague_email);
        if ($is_colleague_exists) {
            print "SKIP [$colleague_email]: already exists in database\n";
        }
        else {
            my @parts = get_name_parts($colleague_name);
            if (@parts) {
                print "ADD [$colleague_email]\n";
                $client_data->add_colleague(
                    $parts[0],
                    $parts[1],
                    $colleague_email,
                    generate_password(),
                );
                $add_count++;
            }
            else {
                print "SKIP [$colleague_name]: can't parse name\n";
            }
        }
    }
    return $add_count;
}

sub add_email_to_responsibles {
    my ($client_data, $responsibles) = @_;

    my $add_count = 0;
    for my $resp (@$responsibles) {
        my $responsible_name = $resp->{'name'};
        my $responsible_email = $resp->{'email'};
        my $is_email_exists = $client_data->is_email_exists($responsible_email);
        if ($is_email_exists) {
            print "SKIP [$responsible_email]: already exists in database\n";
        }
        else {
            my $found_responsibles = $client_data->find_responsible_by_name($responsible_name);
            if (@$found_responsibles == 1) {
                my $found_resp = $found_responsibles->[0];
                my $found_patients = $client_data->get_patients_by_responsible( $found_resp->{'RId'} );
                $add_count += add_email_to_patient_list(
                    $client_data,
                    "patients for responsible [$responsible_name]",
                    $responsible_email,
                    $found_patients,
                    [
                        sub {
                            my ($found_pat) = @_;
                            my $name = $found_pat->{'FName'}.' '.$found_pat->{'LName'};
                            return $responsible_name =~ m/\Q$name/;
                        }
                    ],
                );
            }
            elsif (@$found_responsibles == 0) {
                print "SKIP [$responsible_email]: responsible [$responsible_name] is not found\n";
            }
            else {
                my @rids = map {$_->{'RId'}} @$found_responsibles;
                print "SKIP [$responsible_email]: too many responsibles found [$responsible_name]: ".join(', ', @rids)."\n";
            }
        }
    }
    return $add_count;
}

sub add_email_to_patients {
    my ($client_data, $patients) = @_;

    my $add_count = 0;
    for my $pat (@$patients) {
        my $patient_name = $pat->{'name'};
        my $patient_email = $pat->{'email'};
        my $is_email_exists = $client_data->is_email_exists($patient_email);
        if ($is_email_exists) {
            print "SKIP [$patient_email]: already exists in database\n";
        }
        else {
            my $found_patients = $client_data->find_patients_by_name($patient_name);
            $add_count += add_email_to_patient_list(
                $client_data,
                "patient [$patient_name]",
                $patient_email,
                $found_patients,
                [
                    sub {
                        my ($found_pat) = @_;

                        return $client_data->count_ledgers_by_patient( $found_pat->{'PId'} );
                    }
                ],
            );
        }
    }
    return $add_count;
}

sub add_email_to_patient_list {
    my ($client_data, $message_prefix, $patient_email, $found_patients, $patient_compare) = @_;

    my $add_count = 0;
    if (@$found_patients == 1) {
        my $patient = $found_patients->[0];
        $client_data->add_email(
            $patient->{'PId'},
            $patient->{'RId'},
            $patient_email,
        );
        print "ADD [$patient_email]: $message_prefix to [".$patient->{'PId'}."]\n";
        $add_count++;
    }
    elsif (@$found_patients == 0) {
        print "SKIP [$patient_email]: $message_prefix is not found\n";
    }
    else {
        my $added = 0;
        for my $cond (@$patient_compare) {
            my @patients_with_cond;
            my @patients_without_cond;
            for my $found_pat (@$found_patients) {
                if ($cond->($found_pat)) {
                    push( @patients_with_cond, $found_pat );
                }
                else {
                    push( @patients_without_cond, $found_pat );
                }
            }
            if (@patients_with_cond == 1) {
                my $patient = $patients_with_cond[0];
                $client_data->add_email(
                    $patient->{'PId'},
                    $patient->{'RId'},
                    $patient_email,
                );
                print "ADD [$patient_email]: $message_prefix to [".$patient->{'PId'}."]\n";
                $add_count++;
                $added = 1;
                last;
            }
        }
        unless ($added) {
            my @pids = map {$_->{'PId'}} @$found_patients;
            print "SKIP [$patient_email]: $message_prefix found too many: ".join(', ', @pids)."\n";
        }
    }
    return $add_count;
}

sub read_csv {
    my ($fn, $columns) = @_;

    my $csv = Text::CSV_XS->new(
        {
            'escape_char' => '"',
            'sep_char' => ',',
            'quote_char' => '"',
        }
    );
    $csv->column_names(@$columns);

    my @data;
    open(my $f, "<", $fn) or die "can't read [$fn]: $!";
    while (my $line = $csv->getline_hr($f)) {
        push(@data, $line);
    }
    close($f);
    return \@data;
}

sub get_name_parts {
    my ($name) = @_;

    $name =~ s/^dr\.?\s+//i;
    my @parts = split(/\s+/, $name);
    if (@parts != 2 && $name =~ m/\|/) {
        @parts = split(/\|/, $name);
    }
    if (@parts == 2) {
        return map {trim($_)} @parts;
    }
    else {
        return;
    }
}

sub trim {
    my ($str) = @_;

    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

sub generate_password {
    my @symbols = split(//, "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ123456789");

    return join('', map {$symbols[int(rand()*@symbols)]} 0..7);
}



package DBSource;

use DBI;


sub new {
    my ($class, $db_name) = @_;

    require Sesame::Unified::Client;

    my $client_ref = Sesame::Unified::Client->new('db_name', $db_name);

    my $dbh = get_connection( $db_name );
    my ($type, $id) = ( $client_ref->get_id() =~ m/(\w)(\d+)/ );

    return bless {
        'dbh'     => $dbh,
        'db_name' => $db_name,
        'insert_commands' => [],
    }, $class;
}

sub get_insert_commands {
    my ($self) = @_;

    return $self->{'insert_commands'};
}


sub get_db_name {
    my ($self) = @_;

    return $self->{'db_name'};
}

sub _insert {
    my ($self, $insert_cmd) = @_;

    $self->{'dbh'}->do($insert_cmd);
    push( @{ $self->{'insert_commands'} }, $insert_cmd );
}

sub add_colleague {
    my ($self, $fname, $lname, $email, $password) = @_;

    my $new_id = 1 + $self->{'dbh'}->selectrow_array("SELECT max(id) FROM referring_contacts");

    my $insert_cmd = "INSERT INTO ".$self->{'db_name'}.".referring_contacts (id, fname, lname, practice_name, email, speciality) VALUES (".$self->{'dbh'}->quote($new_id).", ".$self->{'dbh'}->quote($fname).", ".$self->{'dbh'}->quote($lname).", NULL, ".$self->{'dbh'}->quote($email).", NULL)";

    $self->_insert($insert_cmd);

    my $si_insert_cmd = "INSERT INTO ".$self->{'db_name'}.".SI_Doctor (FName, LName, Status, Password, Deleted, WelcomeSent, PrivacyAccepted, ref_contact_id, AutoNotify) VALUES (NULL, NULL, 1, ".$self->{'dbh'}->quote($password).", 0, 0, 0, ".$self->{'dbh'}->quote($new_id).", 0)";

    $self->_insert($si_insert_cmd);

    my $ref_insert_cmd = "INSERT INTO ".$self->{'db_name'}.".referrings (ref_fname, ref_lname, ref_email, ref_contact_id) VALUES (".$self->{'dbh'}->quote($fname).", ".$self->{'dbh'}->quote($lname).", ".$self->{'dbh'}->quote($email).", ".$self->{'dbh'}->quote($new_id).")";

    $self->_insert($ref_insert_cmd);
}

sub get_patients_by_responsible {
    my ($self, $rid) = @_;

    my $patients = $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, RId, FName, LName, Active FROM Patients WHERE RId=?",
        { 'Slice' => {} },
        $rid
    );
}

sub find_patients_by_name {
    my ($self, $name) = @_;

    my $patients = $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, RId, FName, LName, Active FROM Patients WHERE CONCAT(FName, ' ', LName)=?",
        { 'Slice' => {} },
        $name
    );
    unless (@$patients) {
        $patients = $self->{'dbh'}->selectall_arrayref(
            "SELECT PId, RId, FName, LName, Active FROM Patients WHERE ? LIKE CONCAT('%', FName, ' ', LName,'%')",
            { 'Slice' => {} },
            $name
        );
    }
    return $patients;
}

sub find_responsible_by_name {
    my ($self, $name) = @_;

    my $responsibles = $self->{'dbh'}->selectall_arrayref(
        "SELECT RId, FName, LName FROM Responsibles WHERE CONCAT(FName, ' ', LName)=?",
        { 'Slice' => {} },
        $name
    );
    unless (@$responsibles) {
        $responsibles = $self->{'dbh'}->selectall_arrayref(
            "SELECT RId, FName, LName FROM Responsibles WHERE ? LIKE CONCAT('%', FName, ' ', LName,'%')",
            { 'Slice' => {} },
            $name
        );
    }
    return $responsibles;
}

sub add_email {
    my ($self, $pid, $rid, $email) = @_;

    push(
        @{ $self->{'insert_commands'} },
        "INSERT INTO ".$self->{'db_name'}.".Mails (PId, RId, Address, EntryDate, Status, FName, LName, Source) VALUES (".$self->{'dbh'}->quote($pid).", ".$self->{'dbh'}->quote($rid).", ".$self->{'dbh'}->quote($email).", NOW(), 0, NULL, NULL, 4)",
    );

    $self->{'dbh'}->do(
        <<SQL,
INSERT INTO Mails (PId, RId, Address, EntryDate, Status, FName, LName, Source)
VALUES (?, ?, ?, NOW(), 0, NULL, NULL, 4)
SQL
        undef,
        $pid,
        $rid,
        $email,
    );
}

sub is_email_exists {
    my ($self, $email) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM Mails WHERE Address=?",
        undef,
        $email,
    );
}

sub is_colleague_exists {
    my ($self, $email) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM referring_contacts WHERE email=?",
        undef,
        $email,
    );
}

sub count_ledgers_by_patient {
    my ($self, $pid) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM Ledgers WHERE PId=?",
        undef,
        $pid,
    );
}

## static
sub is_client_exists {
    my ($class, $db_name) = @_;

    my $dbh = get_connection();
    return $db_name eq $dbh->selectrow_array("SHOW DATABASES LIKE ?", undef, $db_name);
}

sub get_connection {
    my ($db_name) = @_;

    $db_name ||= '';

    return DBI->connect(
        "DBI:mysql:host=$ENV{SESAME_DB_SERVER}".($db_name?";database=$db_name":""),
        'admin',
        'higer4',
        {
            'RaiseError' => 1,
            'ShowErrorStatement' => 1,
            'PrintError' => 0,
        }
    );
}
