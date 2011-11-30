package ClientData::XMLDB;

use strict;

our $AUTOLOAD;

sub new {
    my ($class, $xml_source, $db_source) = @_;

    return bless {
        'xml_source' => $xml_source,
        'db_source'  => $db_source,
        '_db_method' => {
            'get_patient_appointment' => 1,
        },
    }, $class;
}

sub get_appointments {
    my ($self, $pid, $order, $number) = @_;

    my $appointments = $self->{'xml_source'}->get_appointments($pid, $order, $number);
    for my $app (@$appointments) {
        my $app_info = $self->{'db_source'}->get_patient_appointment( $pid, $app->{'Date'} );
        if (defined $app_info) {
            $app->{'Notified'} = $app_info->{'NotifiedApp'};
            $app->{'Confirm'}  = $app_info->{'Confirm'};
        }
    }
    return $appointments;
}

sub get_appointment_columns {
    my ($self) = @_;

    return [ 'Date', 'Duration', 'Confirm', 'Notified', 'Procedure' ];
}

sub AUTOLOAD {
    my $self = shift;

    my $func_name = $AUTOLOAD;
    $func_name =~ s/^.*://;               # strip fully-qualified portion
    return unless $func_name =~ /[^A-Z]/; # skip methods like DESTROY

    if (exists $self->{'_db_method'}{$func_name}) {
        return $self->{'db_source'}->$func_name(@_);
    } else {
        return $self->{'xml_source'}->$func_name(@_);
    }
}

1;