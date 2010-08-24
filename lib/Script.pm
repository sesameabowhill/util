## $Id:$

package Script;

use strict;
use warnings;

use DataSource::DB;
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
		my $data_source = DataSource::DB->new();
		if ($params->{'read_only'}) {
			$data_source->set_read_only(1);
		}
		@clients = @{ $data_source->expand_client_group( \@clients ) };
	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			$logger->printf("database source: client [%s]", $client_identity);
			my $handler_result = $params->{'client_data_handler'}->($logger, $client_data);
			if (exists $params->{'save_handler_result'}) {
				$params->{'save_handler_result'}->write_data($handler_result);
			}
	    }
	    if (exists $params->{'save_sql_to_file'}) {
			$logger->printf("write sql commands to [%s]", $params->{'save_sql_to_file'});
			$data_source->save_sql_commands_to_file( $params->{'save_sql_to_file'} );
	    }
		if (exists $params->{'save_handler_result'}) {
	        $logger->printf("writing result to [%s]", $params->{'save_handler_result'}->get_file_name());
		}
	    if (exists $params->{'save_commands'}) {
			$logger->printf("write commands commands to [%s]", $params->{'save_commands'});
			$logger->save_commands_to_file( $params->{'save_commands'} );
	    }

		$logger->print_category_stat();
	    my $work_time = time() - $start_time;
	    $logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
	}
	else {
	    print "Usage: $0 <database1> [database2...]\n";
	    exit(1);
	}
}

1;