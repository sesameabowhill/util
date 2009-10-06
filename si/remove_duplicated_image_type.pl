## $Id$
use strict;
use warnings;

use DBI;

my $client_db = $ARGV[0];
unless ($client_db) {
    print "Usage: $0 [database]\n";
    exit(1);
}

my $dbh = get_connection( $client_db );

{
    my $images_types = get_image_types($dbh);
    my %type_by_name;
    for my $type (@$images_types) {
        push( @{ $type_by_name{ $type->{'TypeName'} } }, $type );
    }
    my @duplicated_types = sort grep {@{$type_by_name{$_}}>1} keys %type_by_name;
    #@duplicated_types = ('Photo', 'Ins-Actual Claim');
    for my $type_name (@duplicated_types) {
        my @type_ids = sort {$a <=> $b} map {$_->{'TypeId'}} @{ $type_by_name{ $type_name} };
        print "type [$type_name] ids [".join(', ',@type_ids)."]\n";
        my $type_list = get_images_by_type($dbh, \@type_ids);
        my $main_type;
        if (@$type_list) {
            $main_type = shift @$type_list;
        } else {
            my @types = sort {$a <=> $b} @type_ids;
            $main_type = {
                'date' => 'undef',
                'count' => 0,
                'TypeId' => shift(@types),
            };
        }
        my $main_type_id = $main_type->{'TypeId'};
        my %bad_types = map {$_ => 1} @type_ids;
        delete $bad_types{ $main_type_id };
        my @bad_types = sort {$a <=> $b} keys %bad_types;
        print "replace [".join(', ', @bad_types)."] with [$main_type_id] count [".$main_type->{'count'}."] date [".$main_type->{'date'}."]\n";
        set_image_types($dbh, $main_type_id, \@bad_types);
        delete_image_types($dbh, \@bad_types);
    }
    print "done\n";
}

# SELECT typeid, max(uploaddate), count(*) FROM `SI_Images` WHERE typeid in (119, 120, 121, 122, 123, 124, 125, 126) group by typeid order by 2 desc

sub get_images_by_type {
    my ($dbh, $type_ids) = @_;

    return $dbh->selectall_arrayref(
        "SELECT TypeId, max(uploaddate) AS date, count(*) AS count FROM `SI_Images` WHERE typeid in (".join(', ', @$type_ids).") GROUP BY typeid ORDER BY 2 DESC",
        { Slice => {} }
    );
}

sub get_image_types {
    my ($dbh) = @_;

    return $dbh->selectall_arrayref(
        "SELECT TypeId, TypeName FROM SI_ImagesTypes",
        { Slice => {} }
    );
}

sub set_image_types {
    my ($dbh, $type_id, $types) = @_;

    $dbh->do(
        "UPDATE SI_Images SET TypeId=? WHERE TypeId IN (".join(', ', @$types).")",
        undef,
        $type_id
    );
}

sub delete_image_types {
    my ($dbh, $types) = @_;

    $dbh->do(
        "DELETE FROM SI_ImagesTypes WHERE TypeId IN (".join(', ', @$types).")"
    );
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