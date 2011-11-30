## $Id$
package ClientData::XML;

use strict;

use Storable;
use XML::Twig;

sub new {
    my ($class, $file_name) = @_;

    my $self = bless {
        '_db_name' => ($file_name =~ m/(.*)\.xml/),
    }, $class;
    $self->_load_data(
        $file_name,
        {
            'Patients' => 'patients',
            'Appointments' => 'appointments',
            #'InsuranceContracts' => 'ins_plans',
            'Accounts' => 'accounts',
            'PatientResponsibleLinks' => 'prlinks',
            'Procedures' => 'procedures',
            'AppointmentProcedureLinks' => 'aplinks',
            'Ledgers' => 'ledgers',
        }
    );
    for my $table (sort grep {$_ !~ m/^_/ } keys %$self) {
        printf "table %s: %d\n", $table, scalar @{ $self->{$table} };
    }
    return $self;
}

sub get_db_name {
    my ($self) = @_;

    return $self->{'_db_name'};
}

sub _load_data {
    my ($self, $file_name, $sections) = @_;

    my $dump_name = $file_name.".dump";

    if (-e $dump_name) {
        print "loading [$dump_name]\n";
        %$self = %{ retrieve($dump_name) };
    } else {
        my %twig_roots;
        my %twig_handlers;
        while (my ($xml_section, $name) = each %$sections) {
            $self->{$name} = [];
            $twig_roots{'udbf-3/insert/'.$xml_section} = 1;
            $twig_handlers{$xml_section.'/record'} = sub {
                $self->_add_element($_, $name);
            }
        }
        my $parser = XML::Twig->new(
            'twig_roots' => \%twig_roots,
            'twig_handlers' => \%twig_handlers,
        );
        $parser->parsefile($file_name);
        print "saving [$dump_name]\n";
        store($self, $dump_name);
    }

}

sub get_appointment_columns {
    my ($self) = @_;

    return [ 'Date', 'Duration', 'Procedure' ];
}

sub _add_element {
    my ($self, $elem, $name) = @_;

    push(@{ $self->{$name} }, $elem->simplify());
    my $count = @{ $self->{$name} };
    unless ($count % 1000) {
        print "found $name [$count]\n";
    }
    $elem->purge();
}

sub get_appointment_count {
    my ($self, $pid) = @_;

    $self->_build_appointment_cache();
    my $date_hash = $self->{'_appointment_cache'}{$pid};
    if (defined $date_hash) {
        return scalar keys %$date_hash;
    } else {
        return 0;
    }
}

sub get_appointments {
    my ($self, $pid, $order, $number) = @_;

    $self->_build_appointment_cache();
    my $date_hash = $self->{'_appointment_cache'}{$pid};
    $date_hash ||= {};
    my @dates = sort {$a->{'Date'} cmp $b->{'Date'}} values %$date_hash;
    if ($order eq 'DESC') {
        @dates = reverse @dates;
    }
    my @data;
    for my $app (@dates) {
        push( @data, $app );
        if (@data == $number) {
            last;
        }
    }
    return \@data;
}

sub _build_appointment_cache {
    my ($self) = @_;

    unless (exists $self->{'_appointment_cache'}) {
        my %apps;
        print "building appointment cache: group\n";
        my $all_apps = $self->get_all_appointments();
        for my $app (@$all_apps) {
            $apps{ $app->{'PatientID'} }{ $app->{'Date'} } = $app;
        }
        print "building appointment cache: done\n";
        $self->{'_appointment_cache'} = \%apps;
    }
}

sub _build_procedure_cache {
    my ($self) = @_;

    unless (exists $self->{'_procedure_cache'}) {
        my %procedure;
        print "building procedure cache: procedures\n";
        for my $pr (@{ $self->{'procedures'} }) {
            $procedure{ $pr->{'ID'} } = $pr;
        }
        my %apps;
        print "building procedure cache: group\n";
        for my $link (@{ $self->{'aplinks'} }) {
            my $proc = $procedure{ $link->{'ProcedureID'} };
            push(
                @{ $apps{ $link->{'AppointmentID'} } },
                $proc->{'ProcedureCode'}
            );
        }
        print "building procedure cache: done\n";
        $self->{'_procedure_cache'} = \%apps;
    }
}

sub get_all_appointments {
    my ($self) = @_;

    $self->_build_procedure_cache();
    my @result;
    for my $app (@{ $self->{'appointments'} }) {
        my $date = substr($app->{'AppointmentDateTime'}, 0, 10);
        $app->{'Date'} = $date;
        if (exists $self->{'_procedure_cache'}{$app->{'ID'}}) {
            $app->{'Procedure'} = join ', ', @{ $self->{'_procedure_cache'}{$app->{'ID'}} };
        } else {
            $app->{'Procedure'} = '';
        }
        push(@result, $app);
    }
    @result = sort {$a->{'PatientID'} cmp $b->{'PatientID'}} @result;
    return \@result;
}

sub get_patients {
    my ($self) = @_;

    my @data;
    for my $pat (@{ $self->{'patients'} }) {
        push(
            @data,
            {
                'PId'    => $pat->{'ID'},
                'FName'  => $pat->{'FirstName'},
                'LName'  => $pat->{'LastName'},
                'BDate'  => $pat->{'BirthDate'},
                'Active' => $pat->{'Status'} eq 'Active',
            }
        );
    }
    return \@data;
}

sub get_patient_info {
    my ($self, $pid) = @_;

    $self->_build_patient_cache();
    return $self->{'_patient_cache'}{$pid};
}

sub _build_patient_cache {
    my ($self) = @_;

    unless (exists $self->{'_patient_cache'}) {
        my %patients;
        print "building patient cache: patients\n";
        for my $pat (@{ $self->{'patients'} }) {
            $patients{ $pat->{'ID'} } = $pat;
        }
        print "building patient cache: done\n";
        $self->{'_patient_cache'} = \%patients;
    }
}

sub is_using_insurance {
    my ($self, $pid) = @_;

    $self->_build_ins_plans_cache();
    return $self->{'_patients_with_insurance'}{$pid};
}

sub _build_ins_plans_cache {
    my ($self) = @_;

    unless (exists $self->{'_patients_with_insurance'}) {
        my %apps;
        print "building ins_plans cache: search ledgers\n";
        ## ledgers.AccountID = accounts.ID
        my %account_ids;
        for my $led (@{ $self->{'ledgers'} }) {
            if ($led->{'LedgerType'} eq 'I' || $led->{'LedgerType'} eq 'IP') {
                $account_ids{ $led->{'AccountID'} } = 1;
            }
        }
        print "building ins_plans cache: search prlinks\n";
        ## accounts.PatientResponsibleLinkID = prlinks.ID
        my %prlink_ids;
        for my $ac (@{ $self->{'accounts'} }) {
            if (exists $account_ids{ $ac->{'ID'} }) {
                $prlink_ids{ $ac->{'PatientResponsibleLinkID'} } = 1;
            }
        }
        print "building ins_plans cache: search patients\n";
        ## prlinks.PatientID
        my %patient_ids;
        for my $prl (@{ $self->{'prlinks'} }) {
            if (exists $prlink_ids{ $prl->{'ID'} }) {
                $patient_ids{ $prl->{'PatientID'} } = 1;
            }
        }
        print "building ins_plans cache: done\n";
        $self->{'_patients_with_insurance'} = \%patient_ids;
    }
}

1;