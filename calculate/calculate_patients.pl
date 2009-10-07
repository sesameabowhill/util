#!/usr/bin/perl
## $Id$
use strict;
use warnings;

use lib qw(../lib);

use DataSource::DB;
use ClientData::XML;
use ClientData::XMLDB;


my @clients = @ARGV;
if (@clients) {
	my $data_source = DataSource::DB->new();
    my $start_time = time();
    for my $client_identity (@clients) {
        my $client_data;
        if ($client_identity =~ m/\.xml/) {
            printf "xml source: file [%s]\n", $client_identity;
            $client_data = ClientData::XML->new($client_identity);

            my $db_name = $client_data->get_db_name();
            if ($data_source->is_client_exists($db_name)) {
                printf "use database [%s]\n", $db_name;
                $client_data = ClientData::XMLDB->new(
                    $client_data,
                    $data_source->get_client_data_by_db($db_name),
                );
            }
        } else {
            $client_data = $data_source->get_client_data_by_db($client_identity);
            printf "database source: client [%s]\n", $client_identity;
        }
        write_appointment_report(
            "_appointments.$client_identity.csv",
            $client_data,
        );
        write_noshow_report(
            "_noshows.$client_identity.csv",
            $client_data,
        );
    }
    printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
    print "Usage: $0 <database1> [database2...]\n";
    exit(1);
}

sub write_appointment_report {
    my ($fn, $client_data) = @_;

    print "write appointment report [$fn]\n";

    my $appointment_count = 0;
    my $patients = $client_data->get_patients();
    my @app_columns = @{ $client_data->get_appointment_columns() };

    my %null_app = (
        ( map {$_ => ''} @app_columns ),
        'Date' => '',
        'Confirm' => undef,
        'Notified' => undef,
    );

    open my $output_fh, ">", $fn or die "can't write [$fn]: $!";
    print $output_fh "client;patient;birth;is active;use insurance;# of apps";
    for my $app ('first app', 'last -2 app', 'last -1 app', 'last app') {
        for my $col (@app_columns) {
            print $output_fh ";$app \L$col";
        }
    }
    print $output_fh "\n";
    for my $pat (@$patients) {
        my $app_count = $client_data->get_appointment_count($pat->{'PId'});
        if ($app_count) {
            my $appoinments = $client_data->get_appointments($pat->{'PId'}, 'DESC', 3);
            my $insurance = $client_data->is_using_insurance($pat->{'PId'});
            printf $output_fh (
                "%s;%s, %s;%s;%s;%s;%d",
                $client_data->get_db_name(),
                $pat->{'LName'},
                $pat->{'FName'},
                ( defined $pat->{'BDate'} ? $pat->{'BDate'} : '' ),
                to_human_string($pat->{'Active'}),
                to_human_string( $insurance ),
                $app_count,
            );

            while (@$appoinments < 3) {
                push(@$appoinments, \%null_app);
            }
            my $first_appointment = $client_data->get_appointments($pat->{'PId'}, 'ASC', 1)->[0];
            push(@$appoinments, $first_appointment);
            for my $app (reverse @$appoinments) {
                unless (++$appointment_count%1000) {
                    print "processed [$appointment_count] appointments\n";
                }
                for my $col (@app_columns) {
                    print $output_fh (
                        ";".
                        ( $col eq 'Confirm' || $col eq 'Notified' ?
                            to_human_string( $app->{$col} ) :
                            $app->{$col}
                        )
                    );
                }
            }
            print $output_fh "\n";
        }
    }
    close($output_fh);
}

sub write_noshow_report {
    my ($fn, $client_data) = @_;

    print "write noshow report [$fn]\n";
    my $appointment_count = 0;
    my $apointments = $client_data->get_all_appointments();

    open my $output_fh, ">", $fn or die "can't write [$fn]: $!";
    print $output_fh "client;date;is noshow;patient id; patient name;procedure;duration;notified app;notified noshow;confirm\n";

    for my $app (@$apointments) {
        my $patient = $client_data->get_patient_info($app->{'PatientID'});
        my $app_info = $client_data->get_patient_appointment($app->{'PatientID'}, $app->{'Date'});
        printf $output_fh (
            "%s;%s;%s;%s;%s, %s;%s;%s;%s;%s;%s\n",
            $client_data->get_db_name(),
            $app->{'Date'},
            to_human_string( $app->{'Noshow'} ),
            $app->{'PatientID'},
            $patient->{'LastName'},
            $patient->{'FirstName'},
            $app->{'Procedure'},
            $app->{'Duration'},
            to_human_string( $app_info->{'NotifiedApp'} ),
            to_human_string( $app_info->{'NotifiedNoshow'} ),
            to_human_string( $app_info->{'Confirm'} ),
        );
        unless (++$appointment_count%1000) {
            print "processed [$appointment_count] appointments\n";
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







