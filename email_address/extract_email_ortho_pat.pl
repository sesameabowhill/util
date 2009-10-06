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
	my $office_id = 61;

	my %pids;
	for my $pid (@{ get_appointments_by_officeid($dbh, $office_id) }) {
		$pids{ $pid } = 1;
	}
	for my $pid (@{ get_appointments_history_by_officeid($dbh, $office_id) }) {
		$pids{ $pid } = 1;
	}
	
	my %mail_ids;
	print "RId|PId|BelongsTo|Email|Name|\n";
	for my $pid (sort {$a <=> $b} keys %pids) {
		my $emails = get_emails_by_pid($dbh, $pid);
		for my $email (@$emails) {
			$mail_ids{ $email->{'id'} } = 1;
			$email->{'RId'} = get_reverse_remap($dbh, 3, $email->{'RId'}) // '';
			$email->{'PId'} = get_reverse_remap($dbh, 2, $email->{'PId'});
			printf(
				"%s|%s|%s|%s|%s|\n",
				@$email{'RId', 'PId', 'BelongsTo', 'Email', 'Name'},
			);
		}
	}
	print "DELETE FROM maillist WHERE ml_id in (".join(', ', sort {$a <=> $b} keys %mail_ids).")\n";
#	use Data::Dumper;
#print Dumper(\%pids);
	##

	
}

sub get_reverse_remap {
	my ($dbh, $table_id, $id) = @_;
	
	return $dbh->selectrow_array(
		"SELECT orig_id FROM remap WHERE id=? AND table_id=?",
		undef,
		$id,
		$table_id,
	);
}

sub get_emails_by_pid {
	my ($dbh, $pid) = @_;

	return $dbh->selectall_arrayref(
		"SELECT ml_id AS id, ml_resp_id AS RId, ml_pat_id AS PId, ml_belongsto AS BelongsTo, ml_email AS Email, ml_name AS Name FROM maillist WHERE ml_pat_id=?",
		{ 'Slice' => {} },
		$pid,
	);
}


sub get_appointments_by_officeid {
    my ($dbh, $office_id) = @_;

    return $dbh->selectcol_arrayref(
        "SELECT DISTINCT PId FROM ah_appointments WHERE officeid=?",
        undef,
        $office_id
    );
}

sub get_appointments_history_by_officeid {
    my ($dbh, $office_id) = @_;

    return $dbh->selectcol_arrayref(
        "SELECT DISTINCT PId FROM ah_app_history WHERE officeid=?",
        undef,
        $office_id
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
