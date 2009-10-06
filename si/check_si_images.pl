## $Id$
use strict;

use DBI;

use Sesame::Config;
use Sesame::Unified::Client;
use Sesame::Constants qw( :config );

#/home/sites/site2/web/image_systems/jyavari/si/images

my $client = Sesame::Unified::Client->new('db_name', $ARGV[0]);

my $dbh = get_connection( $client->get_db_name() );

my $qr = $dbh->prepare("SELECT ImageId, PatId, FileName FROM SI_Images");
$qr->execute();
my $counter = 0;
my $total = $qr->rows();
my %invalid_patients;
while (my $r = $qr->fetchrow_hashref()) {
    my $full_filename = sprintf(
        '%s/image_systems/%s/si/images/%s',
        $ENV{'SESAME_WEB'},
        $client->get_db_name(), ## TODO replace with username or ???
        $r->{'FileName'}
    );
    $counter++;
    if (-f $full_filename) {
        unless ($counter % 5000) {
            print "$counter/$total: [$full_filename] - OK\n";
        }
    } else {
        print "$counter/$total: [$full_filename] - not found\n";
        $invalid_patients{ $r->{'PatId'} } ++;
    }
}


print "-"x50, "\n";
if (keys %invalid_patients) {
    print "Images for following patients are missing:\n";
    print "Doctor;Patient FName;Patient LName;BirthDay;Broken Img Count;PID\n";
    for my $pid (keys %invalid_patients) {
        my $patient = get_si_patient_name($dbh, $pid);
        printf(
            "%s;%s;%s;%s;%d;%s\n",
            $client->get_db_name(),
            $patient->{'FName'},
            $patient->{'LName'},
            $patient->{'BDate'},
            $invalid_patients{$pid},
            $pid
        );
    }
} else {
    print "All images are found\n"
}


sub get_si_patient_name {
    my ($dbh, $pid) = @_;

    return $dbh->selectall_arrayref(
        "SELECT FName, LName, BDate FROM SI_Patients WHERE PatId=?",
        { 'Slice' => {} },
        $pid
    )->[0];
}


sub get_connection {
    my ($db_name) = @_;

    $db_name ||= '';

    my $config = Sesame::Config->read_file(CONFIG_FILE_SESAME_CORE);

    return DBI->connect(
            "DBI:mysql:host=$ENV{SESAME_DB_SERVER}".($db_name?";database=$db_name":""),
            $config->{'database_access'}->{'user'},
            $config->{'database_access'}->{'password'},
            {
                    RaiseError => 1,
                    ShowErrorStatement => 1,
                    PrintError => 0,
            }
    );
}