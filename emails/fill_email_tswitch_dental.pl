## $Id$
use strict;
use warnings;

use DBI;

use constant FILE_PATIENTS_MAILS     => 'mails.patients.txt';
use constant FILE_RESPONSIBLES_MAILS => 'mails.responsibles.txt';

my $client_db = $ARGV[0];
unless ($client_db) {
    print "Usage: $0 [database]\n";
    exit(1);
}

my $dbh = get_connection( $client_db );

{
    my $data = load_csv_file( FILE_PATIENTS_MAILS );
    for my $l (@$data) {
        @$l{'FName', 'LName'} = split_name( $l->{'Name'} );

        my $ids = get_patient_id($dbh, $l->{'FName'}, $l->{'LName'});
        if ($ids) {
            unless (email_exists_by_pid($dbh, $l->{'Email'}, $ids->{'PId'})) {
                add_email($dbh, $ids->{'PId'}, $ids->{'RId'}, $l->{'Email'});
                printf "adding pat [%s] to patient [%s] responsible [%s]\n", $l->{'Email'}, $ids->{'PId'}, $ids->{'RId'};
            }
        } else {
            printf("[%s] [%s] <- patient not found\n", $l->{'FName'}, $l->{'LName'});
        }
    }
}

{
    my $data = load_csv_file( FILE_RESPONSIBLES_MAILS );
    for my $l (@$data) {
        @$l{'FName', 'LName'} = split_name( $l->{'Name'} );

        my $ids = get_responsible_id($dbh, $l->{'FName'}, $l->{'LName'});
        if ($ids) {
            unless (email_exists_by_rid($dbh, $l->{'Email'}, $ids->{'RId'})) {
                my $patients = get_patients_by_responsible( $dbh, $ids->{'RId'} );
                for my $pid (@$patients) {
                    #my $pid = $t;
                    add_email($dbh, $pid, $ids->{'RId'}, $l->{'Email'});
                    printf "adding resp [%s] to patient [%s] responsible [%s]\n", $l->{'Email'}, $pid, $ids->{'RId'};
                }
            }
        #    add_email($dbh, $ids->{'PId'}, $ids->{'RId'}, $l->{'Email'});
        } else {
            printf("[%s] [%s] <- responsible not found\n", $l->{'FName'}, $l->{'LName'});
        }
    }
}


#
#my $qr = $dbh->prepare("SELECT ImageId, PatId, FileName FROM SI_Images");
#$qr->execute();
#my $counter = 0;
#my $total = $qr->rows();
#my %invalid_patients;
#while (my $r = $qr->fetchrow_hashref()) {
#}

sub get_patient_id {
    my ($dbh, $fname, $lname) = @_;

    #my $result = $dbh->selectall_arrayref(
    #    "SELECT PId, RId FROM Patients WHERE FName=? AND LName=? LIMIT 1",
    #    { 'Slice' => {} },
    #    $fname, $lname
    #);
    #unless (@$result) {
    #    $result = $dbh->selectall_arrayref(
    #        "SELECT PId, RId FROM Patients WHERE CONCAT(FName, ' ', LName) LIKE ? LIMIT 1",
    #        { 'Slice' => {} },
    #        string_to_like("$fname $lname"),
    #    );
    #}
    #return ( @$result ? $result->[0] : undef );
    return _search_by_name($dbh, 'PId, RId', 'Patients', $fname, $lname);
}

sub get_responsible_id {
    my ($dbh, $fname, $lname) = @_;

    return _search_by_name($dbh, 'RId', 'Responsibles', $fname, $lname);
}

sub get_patients_by_responsible {
    my ($dbh, $rid) = @_;

    return $dbh->selectcol_arrayref(
        "SELECT PId FROM Patients WHERE RId=?",
        undef,
        $rid
    );
}

sub _search_by_name {
    my ($dbh, $fields, $table, $fname, $lname) = @_;

    my $result = $dbh->selectall_arrayref(
        "SELECT $fields FROM $table WHERE FName=? AND LName=? LIMIT 1",
        { 'Slice' => {} },
        $fname, $lname
    );
    unless (@$result) {
        $result = $dbh->selectall_arrayref(
            "SELECT $fields FROM $table WHERE CONCAT(FName, ' ', LName) LIKE ? LIMIT 1",
            { 'Slice' => {} },
            string_to_like("$fname $lname"),
        );
    }
    return ( @$result ? $result->[0] : undef );
}

sub email_exists_by_pid {
    my ($dbh, $email, $pid) = @_;

    my ($count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM Mails WHERE PId=?",
        { 'Slice' => {} },
        $pid
    );
    return $count;
}

sub email_exists_by_rid {
    my ($dbh, $email, $rid) = @_;

    my ($count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM Mails WHERE RId=?",
        { 'Slice' => {} },
        $rid
    );
    return $count;
}

sub add_email {
    my ($dbh, $pid, $rid, $email) = @_;

    my $insert_q = $dbh->prepare("INSERT INTO Mails (PId,RId,Address,EntryDate,Status,FName,LName,Source) VALUES (?,?,?,NOW(),0,NULL,NULL,4)");
    $insert_q->execute($pid, $rid, $email);
}

sub load_csv_file {
    my ($fn) = @_;

    open(my $f, '<', $fn) or die "can't read [$fn]: $!";
    my @columns = map {trim(strip_quotes($_))} split /;/, <$f>;
    my @lines;
    while(<$f>) {
        my %r;
        @r{ @columns } = map {trim(strip_quotes($_))} split /;/, $_;
        push( @lines, \%r );
    }
    close($f);
    return \@lines;
}

sub strip_quotes {
    my ($str) = @_;

    if ($str =~ m/^"(.*)"$/m) {
        $str = $1;
        $str =~ s/""/"/g;
    }
    return $str;
}

sub split_name {
    my ($str) = @_;

    my @name_parts = split( / /, $str );
    my $lname = pop @name_parts;
    my $fname = join(' ', @name_parts);
    return ($fname, $lname);
}

sub trim {
    my ($str) = @_;
    $str =~ s/\s+$//;
    $str =~ s/^\s+//;
    return $str;
}

sub string_to_like {
    my ($str) = @_;

    $str =~ s/\b/ /g;
    $str =~ s/\s+/%/g;
    return $str;
}

sub get_connection {
    my ($db_name) = @_;

    $db_name ||= '';

    return DBI->connect(
            "DBI:mysql:host=$ENV{SESAME_DB_SERVER}".($db_name?";database=$db_name":""),
            'admin',
            'higer4',
            {
                    RaiseError => 1,
                    ShowErrorStatement => 1,
                    PrintError => 0,
            }
    );
}