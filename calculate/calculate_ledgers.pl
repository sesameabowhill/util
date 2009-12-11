## $Id$
use strict;
use warnings;


my @clients = @ARGV;
if (@clients) {
    my $start_time = time();
    for my $client_identity (@clients) {
        my $client_data = DBSource->new($client_identity);
        printf "database source: client [%s]\n", $client_identity;
        write_ledgers_report(
            "_ledgers.$client_identity.csv",
            $client_data,
        );
    }
    printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
    print "Usage: $0 <database1> [database2...]\n";
    exit(1);
}

sub write_ledgers_report {
    my ($fn, $client_data) = @_;

    print "write ledgers report [$fn]\n";

    my $responsibles = $client_data->get_responsibles();
    my %resp_with_ledgers = map {$_ => 1} @{ $client_data->get_ledgers_responsibles() };
    @$responsibles = grep {exists $resp_with_ledgers{ $_->{'RId'} }} @$responsibles;

    my %unique_patient_names;
    for my $pat (@{ $client_data->get_unique_patient_names() }) {
        $unique_patient_names{ $pat->{'FName'} }{ $pat->{'LName'} } = $pat;
    }

    open my $output_fh, ">", $fn or die "can't write [$fn]: $!";
    print $output_fh "client;responsible;patient;app date;prev balance;period balance;insurance payment;last insurance payment date;private payment;last private payment date;first charge date;sesame payment sum;sesame last payment date;sesame payment type;sesame payment provider";
    print $output_fh "\n";

    my $appointment_count = 0;

    my $date_interval = $client_data->get_ledgers_date_interval();

    for my $resp (@$responsibles) {
        my $patients = $client_data->get_patients_by_responsible( $resp->{'RId'} );
        for my $pat (@$patients) {
            my $appointments = $client_data->get_appointments( $pat->{'PId'} );
            if (@$appointments) {
                my %search_end;
                for my $app_index (1..@$appointments) {
                    my $start = $appointments->[ $app_index-1 ]{'Date'};
                    my $end = (
                        $app_index == @$appointments ?
                            $date_interval->{'max'} :
                            $appointments->[ $app_index ]{'Date'}
                    );
                    $search_end{ $start } = $end;
                }

                for my $app (@$appointments) {
                    my $start_ledgers = $client_data->get_ledgers(
                        $resp->{'RId'},
                        $date_interval->{'min'},
                        $app->{'Date'},
                    );
                    my $start_ledgers_stat = get_ledgers_stat( $start_ledgers );

                    my $ledgers = $client_data->get_ledgers(
                        $resp->{'RId'},
                        $app->{'Date'},
                        $search_end{ $app->{'Date'} },
                    );
                    my $ledgers_stat = get_ledgers_stat( $ledgers );

                    my $payment_stat = {
                        'types' => [],
                        'providers' => [],
                    };
                    if (exists $unique_patient_names{ $pat->{'FName'} }{ $pat->{'LName'} }) {
                        my $payments = $client_data->get_opse_payments(
                            $pat->{'FName'},
                            $pat->{'LName'},
                            $app->{'Date'},
                            $search_end{ $app->{'Date'} },
                        );
                        if (@$payments) {
                            $payment_stat = get_ledgers_stat( $payments );
                            $payment_stat->{'last_date'} = substr($payments->[-1]{'DateTime'}, 0, 10);
                        }
                    }

                    unless (++$appointment_count%100) {
                        print "processed [$appointment_count] appointments\n";
                    }
                    printf $output_fh (
                        "%s;%s, %s;%s, %s;%s;%.2f;%.2f;%s;%s;%s;%s;%s;%s;%s;%s;%s",
                        $client_data->get_db_name(),
                        $resp->{'LName'},
                        $resp->{'FName'},
                        $pat->{'LName'},
                        $pat->{'FName'},
                        $app->{'Date'},
                        ($start_ledgers_stat->{'sum'} || 0),
                        ($ledgers_stat->{'sum'} || 0),
                        empty_number( $ledgers_stat->{'sum_by_type'}{'I'} ),
                        ($ledgers_stat->{'last_payment_date'}{'I'} || ''),
                        empty_number( $ledgers_stat->{'sum_by_type'}{'P'} ),
                        ($ledgers_stat->{'last_payment_date'}{'P'} || ''),
                        ($ledgers_stat->{'first_payment_date'}{'C'} || ''),
                        empty_number( $payment_stat->{'sum'} ),
                        ($payment_stat->{'last_date'} || '' ),
                        join(', ', @{ $payment_stat->{'types'} }),
                        join(', ', @{ $payment_stat->{'providers'} }),
                    );
                    print $output_fh "\n";
                }
            }
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

sub empty_number {
    my ($num) = @_;

    if (defined $num && length $num) {
        return sprintf("%.2f", $num);
    }
    else {
        return "";
    }
}

sub get_ledgers_stat {
    my ($ledgers) = @_;

    my $sum = 0;
    my %sum_by_type;
    my %last_payment_date;
    my %first_payment_date;
    my %types;
    my %providers;
    for my $l (@$ledgers) {
        $types{ $l->{'Type'} } = 1;
        if (exists $l->{'Provider'}) {
            $providers{ $l->{'Provider'} } = 1;
        }
        if ($l->{'Amount'} != 0) {
            $sum += $l->{'Amount'};
            $sum_by_type{ $l->{'Type'} } += $l->{'Amount'};
            $last_payment_date{ $l->{'Type'} } = substr($l->{'DateTime'}, 0, 10);
            unless (exists $first_payment_date{ $l->{'Type'} }) {
                $first_payment_date{ $l->{'Type'} } = substr($l->{'DateTime'}, 0, 10);
            }
        }
    }
    return {
        'sum' => $sum,
        'types' => [ sort keys %types ],
        'providers' => [ sort keys %providers ],
        'sum_by_type' => \%sum_by_type,
        'last_payment_date' => \%last_payment_date,
        'first_payment_date' => \%first_payment_date,
    };
}


package DBSource;

use DBI;
use Readonly;


BEGIN {
    Readonly my %TABLES_BY_TYPE => (
        'o' => 'Ortho',
        'd' => 'Dental',
        'ortho' => {
            'patient' => 'patients',
            'patient.active' => 'Status',
            'appointment' => 'ah_appointments',
            'appointment_history' => 'ah_app_history',
        },
        'dental' => {
            'patient' => 'Patients',
            'patient.active' => 'Active',
            'appointment' => 'Appointments',
            'appointment_history' => 'AppointmentsHistory',
        },
    );

    sub new {
        my ($class, $db_name) = @_;

        require Sesame::Unified::Client;

        my $client_ref = Sesame::Unified::Client->new('db_name', $db_name);

        my $dbh = get_connection( $db_name );
        my ($type, $id) = ( $client_ref->get_id() =~ m/(\w)(\d+)/ );
        my $opse_id = $dbh->selectrow_array(
            "SELECT CID FROM opse.clients WHERE Category=? AND OuterId=?",
            undef,
            $TABLES_BY_TYPE{ $type },
            $id,
        );


        return bless {
            'tables'  => $TABLES_BY_TYPE{ $client_ref->get_client_type() },
            'dbh'     => $dbh,
            'db_name' => $db_name,
            'opse_id' => $opse_id,
        }, $class;
    }
}

#sub get_db_name {
#    my ($self) = @_;
#
#    return $self->{'db_name'};
#}

#sub get_opse_payments {
#    my ($self, $fname, $lname, $from, $to) = @_;
#
#    return $self->{'dbh'}->selectall_arrayref(
#        "SELECT Time AS DateTime, Provider, FName, LName, -Amount AS Amount, PaymentType AS Type FROM opse.payment_log WHERE FName=? AND LName=? AND Time BETWEEN CONCAT(?, ' 00:00:00') AND CONCAT(?, ' 00:00:00') - INTERVAL 1 SECOND AND if(Provider='PRI', TResult='OK', Provider='Malse') ORDER BY Time",
#		{ 'Slice' => {} },
#        $fname,
#        $lname,
#        $from,
#        $to,
#    );
#}


#sub get_unique_patient_names {
#    my ($self) = @_;
#
#    return $self->{'dbh'}->selectall_arrayref(
#        "SELECT FName, LName, PId FROM Patients GROUP BY 1,2 HAVING COUNT(*)=1",
#		{ 'Slice' => {} },
#    );
#}

sub get_patients_by_responsible {
    my ($self, $rid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, FName, LName, BDate, Active FROM Patients WHERE RId=? ORDER BY 3,2",
		{ 'Slice' => {} },
        $rid,
    );
}


#sub get_responsibles {
#    my ($self) = @_;
#
#    return $self->{'dbh'}->selectall_arrayref(
#        "SELECT RId, FName, LName FROM Responsibles ORDER BY 3,2",
#		{ 'Slice' => {} },
#    );
#}

#sub get_appointments {
#    my ($self, $pid) = @_;
#
#    return $self->{'dbh'}->selectall_arrayref(
#        "SELECT Date FROM ".$self->{'tables'}->{'appointment_history'}." WHERE PId=? AND Why='moved' GROUP BY Date ORDER BY Date",
#		{ 'Slice' => {} },
#        $pid,
#    );
#}

sub get_ledgers_responsibles {
    my ($self) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT DISTINCT RId FROM Ledgers",
    );

}

#sub get_ledgers_date_interval {
#    my ($self) = @_;
#
#    return $self->{'dbh'}->selectrow_hashref(
#        "SELECT LEFT(MAX(DateTime), 10) as max, LEFT(MIN(DateTime), 10) as min FROM Ledgers",
#    );
#}

#sub get_ledgers {
#    my ($self, $rid, $from, $to) = @_;
#
#    return $self->{'dbh'}->selectall_arrayref(
#        "SELECT DateTime, Amount, Description, Type FROM Ledgers WHERE RId=? AND DateTime BETWEEN CONCAT(?, ' 00:00:00') AND CONCAT(?, ' 00:00:00') - INTERVAL 1 SECOND ORDER BY DateTime",
#		{ 'Slice' => {} },
#        $rid,
#        $from,
#        $to,
#    );
#}


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
