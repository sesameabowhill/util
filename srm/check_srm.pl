## $Id$
use strict;
use warnings;

use File::Spec;

my @run = @ARGV;
if (@run) {
    my $start_time = time();
    my $data_source = DBSource->new();

    fix_containers($data_source);
    my $missing_resources = check_resources($data_source);
    filter_missing_banners($data_source, $missing_resources);
    print "statements\n";
    for my $sql (@{ $data_source->get_statements() }) {
        print "$sql;\n";
    }
    print "affected clients\n";
    my $client_count = 0;
    for my $client (@{ $data_source->get_affected_clients() }) {
        $client_count++;
        print "$client_count: $client\n";
    }

    if (@$missing_resources) {
        my $min_date = $missing_resources->[0]{'date'};
        for my $res (@$missing_resources) {
            if ($min_date gt $res->{'date'}) {
                $min_date = $res->{'date'};
            }
        }
        print "first missing resource date [$min_date]\n";
    }

    printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
    print "Usage: $0 <run>\n";
    exit(1);
}


sub check_resources {
    my ($data_source) = @_;

    my $resources = $data_source->get_srm_resources();
    my @missing_resources;
    for my $res (@$resources) {
        my ($extention) = ( $res->{'path_from'} =~ m/\.(\w+)\s*$/ );
        my $file = File::Spec->join(
            $ENV{'SESAME_WEB'},
            'sesame_store',
            $res->{'container'},
            $res->{'id'}.'.'.( defined $extention ? $extention : '' ),
        );
        if (-e $file) {
            print "SKIP [".$res->{'id'}."]: file exists\n";
        }
        else {
            print "[$file] not found\n";
            push @missing_resources, $res;
        }
    }
    return \@missing_resources;
}

sub filter_missing_banners {
    my ($data_source, $missing_resources) = @_;

    for my $res (@$missing_resources) {
        my $db = $res->{'container'};
        if ( $data_source->is_client_exists($db) ) {
            my $client_ref = $data_source->client_by_db($db);
            my $property_name = 'WebAccount->BannerId';
            my $web_banner_id = $data_source->get_client_property(
                $client_ref,
                $property_name,
            );
            my $email_message_guids = $data_source->get_email_messaging_guids(
                $client_ref->get_id(),
            );
            my %used_guids = map { $_ => { 'email' => 1 } } keys %$email_message_guids;
            if ($web_banner_id) {
                $used_guids{$web_banner_id}{'web'} = 1;
            }
            my $guid = $res->{'id'};
            if (exists $used_guids{$guid}) {
                if (exists $used_guids{$guid}{'email'}) {
                    print "CLIENT [".$client_ref->get_db_name()."]: REMOVE guid [$guid]: guid is used in [email]\n";
                    $data_source->remove_guid_from_email_settings($client_ref, $guid);
                }
                if (exists $used_guids{$guid}{'web'}) {
                    print "CLIENT [".$client_ref->get_db_name()."]: REMOVE guid [$guid]: guid is used in [web]\n";
                    $data_source->remove_guid_from_properties($client_ref, $property_name, $guid);
                }
                $data_source->remove_resource($guid);
            }
            else {
                print "CLIENT [".$client_ref->get_db_name()."]: REMOVE guid [$guid]: is not used\n";
                $data_source->remove_resource($guid);
            }
        }
        else {
            print "SKIP client [$db]: not found\n";
        }
    }
}

sub fix_containers {
    my ($data_source) = @_;

    my $clients = $data_source->get_clients();
    for my $client (@$clients) {
        my $container = $client->get_db_name();
        my $folder =  my $file = File::Spec->join(
            $ENV{'SESAME_WEB'},
            'sesame_store',
            $container,
        );
        if (-d $folder) {
            print "SKIP container [".$container."]: folder exists\n";
        }
        else {
            print "CREATE container [".$container."]\n";
            mkdir($folder) or die "can't create folder [$folder]: $!";
        }
    }
}




package DBSource;

use DBI;
use Sesame::Unified::Client;
use Sesame::Unified::ClientProperties;

sub new {
    my ($class) = @_;

    return bless {
        'dbh' => get_connection(),
        'statements' => [],
        'affected_clients' => {},
    }, $class;
}

sub get_statements {
    my ($self) = @_;

    return [ sort @{ $self->{'statements'} } ];
}

sub get_affected_clients {
    my ($self) = @_;

    return [ sort keys %{ $self->{'affected_clients'} } ];
}

sub remove_resource {
    my ($self, $guid) = @_;

    push(
        @{ $self->{'statements'} },
        "DELETE FROM srm.resources WHERE id=" .
            $self->{'dbh'}->quote($guid)." LIMIT 1",
    );
}

sub remove_guid_from_email_settings {
    my ($self, $client_ref, $guid) = @_;

    my $table_name = ( $client_ref->get_client_type() eq 'ortho' ? 'properties' : 'profile' );
    push(
        @{ $self->{'statements'} },
        "UPDATE email_messaging.reminder_settings SET image_guid='' WHERE client_id=" .
            $self->{'dbh'}->quote($client_ref->get_id())." AND image_guid=" .
            $self->{'dbh'}->quote($guid),
    );
    $self->{'affected_clients'}{ $client_ref->get_db_name() } = 1;
}

sub remove_guid_from_properties {
    my ($self, $client_ref, $param, $guid) = @_;

    my $table_name = ( $client_ref->get_client_type() eq 'ortho' ? 'properties' : 'profile' );
    push(
        @{ $self->{'statements'} },
        "UPDATE ".$client_ref->get_db_name().".$table_name SET SVal=NULL " .
            "WHERE PKey=".$self->{'dbh'}->quote($param)." AND SVal=" .
            $self->{'dbh'}->quote($guid),
    );
    $self->{'affected_clients'}{ $client_ref->get_db_name() } = 1;
}

sub get_srm_resources {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, container, path_from, date FROM srm.resources",
        { 'Slice' => {} },
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

sub client_by_db {
    my ($self, $db) = @_;

    return Sesame::Unified::Client->new('db_name', $db);
}

sub get_clients {
    my ($self) = @_;

    return Sesame::Unified::Client->get_all_clients();
}

sub get_email_messaging_guids {
    my ($self, $client_id) = @_;

    return {
        map {@$_}
        grep {defined $_->[0] && length $_->[0]}
        @{
            $self->{'dbh'}->selectall_arrayref(
                "SELECT image_guid, count(*) FROM email_messaging.reminder_settings WHERE client_id=? GROUP BY 1",
                undef,
                $client_id,
            )
        }
    };
}

## static
sub is_client_exists {
    my ($class, $db_name) = @_;

    my $dbh = get_connection();
    my $db = $dbh->selectrow_array("SHOW DATABASES LIKE ?", undef, $db_name);
    return defined $db && $db eq $db_name;
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
