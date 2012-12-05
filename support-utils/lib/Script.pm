## $Id$

package Script;

use strict;
use warnings;

use DateUtils;
use Logger;

## posible params:
##   'save_sql_to_file'
##   'save_commands_to_file'
##   'save_handler_result'
##   'read_only'
##   'client_data_handler'

sub simple_client_loop {
	my ($class, $args, $params) = @_;

	$|=1;
	my (@clients) = @$args;
	if (@clients) {
	    my $start_time = time();
	    my $logger = Logger->new();
	    ## choose data source by first username
		($clients[0], my $data_source) = $class->choose_data_source_by_username($clients[0]);
		if ($params->{'read_only'}) {
			$data_source->set_read_only(1);
		}
		$logger->printf("data source [%s]", $data_source->get_connection_info());

		if ($data_source->can('expand_client_group')) {
			@clients = @{ $data_source->expand_client_group( \@clients ) };
		}
	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			$logger->printf("client username [%s]", $client_identity);
			my $handler_result = $params->{'client_data_handler'}->($logger, $client_data);
			if (exists $params->{'save_handler_result'}) {
				$params->{'save_handler_result'}->write_data($handler_result);
			}
	    }
	    if (exists $params->{'save_sql_to_file'}) {
	    	my $fn = $params->{'save_sql_to_file'};
	    	if ($fn =~ m{%s}) {
	    		$fn = sprintf($fn, (@clients == 1 ? $clients[0] : DateUtils->get_current_date_filename()));
	    	}
			$logger->printf("write sql commands to [%s]", $fn);
			$data_source->save_sql_commands_to_file($fn);
	    }
		if (exists $params->{'save_handler_result'}) {
	    	my $fn = $params->{'save_handler_result'}->get_file_name();
	        $logger->printf("writing result to [%s]", $params->{'save_handler_result'}->get_file_name());
		}
	    if (exists $params->{'save_commands'}) {
	    	my $fn = $params->{'save_commands'};
			$logger->printf("write commands commands to [%s]", $fn);
			$logger->save_commands_to_file($fn);
	    }

		$logger->print_category_stat();
	    my $work_time = time() - $start_time;
	    $logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
	}
	else {
	    printf(
	    	"Usage: %s %s<database1> [database2...]\n",
	    	$0,
	    	( exists $params->{'options'} ? $params->{'options'}." " : "" )
	    );
	    exit(1);
	}
}

sub choose_data_source_by_username {
	my ($class, $username, $db_connection_string) = @_;

	if ($username =~ s/^pms_migration_backup://) {
		require DataSource::PMSMigrationBackup;
		return ($username, DataSource::PMSMigrationBackup->new());
	}
	elsif ($username =~ s/^4:// ) {
		require DataSource::DB;
		return ($username, DataSource::DB->new_4($db_connection_string));
	}
	else {
		require DataSource::DB;
		return ($username, DataSource::DB->new(undef, $db_connection_string));
	}

}

1;