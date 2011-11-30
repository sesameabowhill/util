#!/usr/bin/perl
## $Id$
use strict;
use warnings;

use lib qw( ../lib );

use File::Spec;

use DataSource::DB;

my @run = @ARGV;
if (@run) {
    my $start_time = time();
    my $data_source = DataSource::DB->new();

    #fix_containers($data_source);
    my $missing_resources = check_resources($data_source);
    filter_missing_banners($data_source, $missing_resources);
#    print "statements\n";
#    for my $sql (@{ $data_source->get_statements() }) {
#        print "$sql;\n";
#    }
#    print "affected clients\n";
#    my $client_count = 0;
#    for my $client (@{ $data_source->get_affected_clients() }) {
#        $client_count++;
#        print "$client_count: $client\n";
#    }

#    if (@$missing_resources) {
#        my $min_date = $missing_resources->[0]{'date'};
#        for my $res (@$missing_resources) {
#            if ($min_date gt $res->{'date'}) {
#                $min_date = $res->{'date'};
#            }
#        }
#        print "first missing resource date [$min_date]\n";
#    }

    printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
    print "Usage: $0 <run>\n";
    exit(1);
}


sub check_resources {
    my ($data_source) = @_;

    my $resources = $data_source->get_all_srm_resources();
    my @missing_resources;
    for my $res (@$resources) {
        my ($extention) = ( $res->{'path_from'} =~ m/\.(\w+)\s*$/ );
        my $file = File::Spec->join(
            $ENV{'SESAME_COMMON'},
            'srm',
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




