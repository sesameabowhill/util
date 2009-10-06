## $Id$
use strict;
use warnings;


my @clients = @ARGV;
if (@clients) {
    my $start_time = time();
    my $data_source = DBSource->new();

    write_noshow_report("_hhf.csv", $data_source);

    printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
    print "Usage: $0 <run>\n";
    exit(1);
}


sub write_noshow_report {
    my ($fn, $data_source) = @_;

    print "write HHF report [$fn]\n";

    open my $output_fh, ">", $fn or die "can't write [$fn]: $!";
    print $output_fh "client;is active;hhf at 2009;hhf at 2008;total hhf count\n";

    my $clients = $data_source->get_clients();
    for my $client_ref (@$clients) {
        my $hhf_guid = $data_source->get_client_property($client_ref, 'HHF->GUID');
        if (defined $hhf_guid) {
            my $hhf_id = $data_source->get_hhf_id_by_guid($hhf_guid);
            if ($hhf_id) {
                print "PROCESS [".$client_ref->get_db_name()."]: get data for [$hhf_id]\n";
                printf $output_fh (
                    "%s;%s;%d;%d;%d\n",
                    $client_ref->get_db_name(),
                    $client_ref->is_active(),
                    $data_source->get_hhf_forms_count_by_year($hhf_id, 2009),
                    $data_source->get_hhf_forms_count_by_year($hhf_id, 2008),
                    $data_source->get_hhf_forms_count_by_year($hhf_id, '%'),
                );
            }
            else {
                print "SKIP [".$client_ref->get_db_name()."]: missing data\n";
            }
        }
        else {
            print "SKIP [".$client_ref->get_db_name()."]: no HHF\n";
        }
    }

    close($output_fh);
}

sub to_human_string {
    my ($confirmed) = @_;

    return (
        defined $confirmed ?
            ( $confirmed ? 'yes' : 'no' ) :
            ''
    );
}



package DBSource;

use DBI;
use Sesame::Unified::Client;
use Sesame::Unified::ClientProperties;

sub new {
    my ($class) = @_;

    return bless {
        'dbh' => get_connection(),
    }, $class;
}

sub get_clients {
    my ($self) = @_;

    return Sesame::Unified::Client->get_all_clients();
}

sub get_hhf_id_by_guid {
    my ($self, $hhf_guid) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT id FROM hhf.clients WHERE guid=?",
        undef,
        $hhf_guid
    );
}

sub get_hhf_forms_count_by_year {
    my ($self, $hhf_id, $year) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM hhf.applications WHERE cl_id=? AND filldate LIKE CONCAT(?,'-%')",
        undef,
        $hhf_id,
        $year,
    );

}

sub get_client_property {
    my ($self, $client_ref, $param) = @_;

    $self->{'dbh'}->do("USE ".$client_ref->get_db_name());
    my $client_prop = Sesame::Unified::ClientProperties->new(
        $client_ref->get_client_type(),
        $self->{'dbh'},
    );

    return $client_prop->get_property($param);
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
