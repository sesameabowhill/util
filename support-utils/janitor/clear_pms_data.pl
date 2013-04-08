#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use Getopt::Long;

use lib '../lib';

use DataSource::DB;
use Logger;

{
	my $table = ':all';
	my $type = 'id';
	my $batch_size = 1000;
	my $sleep = 0;
	my $db_connection_string_for_read = undef;
	my $db_connection_string_for_write = undef;
	GetOptions(
		'table=s' => \$table,
		'type=s' => \$type,
		'batch-size=s' => \$batch_size,
		'sleep=s' => \$sleep,
		'db-connection-string-for-write=s' => \$db_connection_string_for_write,
		'db-connection-string-for-read=s' => \$db_connection_string_for_read,
	);

	$|=1;
	my $logger = Logger->new();

	my @clients = @ARGV;

	if (@clients && $table) {
		my $data_source = DataSource::DB->new(undef, $db_connection_string_for_write);
		my $read_data_source;
		if (defined $db_connection_string_for_read) {
			$read_data_source = DataSource::DB->new(undef, $db_connection_string_for_read);
			$read_data_source->set_read_only(1);
			$logger->printf("write ids to [%s]", $data_source->get_connection_info());
			$logger->printf("read ids from [%s]", $read_data_source->get_connection_info());
		} else {
			$logger->printf("read/write ids from/to [%s]", $data_source->get_connection_info());
			$read_data_source = $data_source;
		}
		@clients = @{ $data_source->expand_client_group( \@clients ) };

	    my $start_time = time();
	    my $output_fn = "_clear_data.sql";
	    my $output = (defined $db_connection_string_for_read ? 
	    	Output::DB->new($logger, $data_source, $sleep, $batch_size) :
	    	Output::File->new($logger, $output_fn, $batch_size)
    	);

	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			my $read_client_data = $read_data_source->get_client_data_by_db($client_identity);
			$logger->printf("client username [%s]", $client_identity);
			if ($type eq 'id') {
				copy_data_by_id($logger, $output, $client_data, $read_client_data, $table);
			}
			else {
				copy_data_by_client_id($logger, $output, $client_data, $table);
			}
		}

		$logger->print_category_stat();

		$output->close();

		unless (defined $db_connection_string_for_read) {
			$logger->printf("write result to [%s]", $output_fn);
		}

	    my $work_time = time() - $start_time;
	    $logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
	}
	else {
		print "Usage: $0 <--table=...|:all> [--type=id|client_id] [--batch-size=100] [--sleep=0]  <client_db1> ...\n";
		print "Database connections: [--db-connection-string-for-write=user:password\@host:port/schema] [--db-connection-string-for-read=user:password\@host:port/schema]\n"
		print "Use --sleep=file:sleep.txt to read value from sleep.txt\n";
		exit(1);
	}
}

sub copy_data_by_id {
    my ($logger, $output, $client_data, $read_data_source, $tables) = @_;

    if ($tables eq ':all') {
    	$tables = join(',', @{ $client_data->get_vesioned_table_names() });
    }

	my $last_initial_version_id = $client_data->get_last_initial_version_id();
    $logger->printf("last initial_version_id [%d]", $last_initial_version_id);
    for my $table (split(',', $tables)) {
	    $logger->printf("reading unique ids from [%s]", $table);
	    my $ids = $read_data_source->get_unique_ids_from_vesioned_table($table);
	    $logger->printf("[%s] unique ids in [%s]", scalar @$ids, $table);
	    my $output_table = $output->start_table($table, $last_initial_version_id, $client_data->get_username());
	    for my $id (@$ids) {
	    	$output_table->detete_id($id);
	    }
	    $output_table->flush();
    }
}

sub copy_data_by_client_id {
    my ($logger, $output, $client_data, $tables) = @_;

    if ($tables eq ':all') {
    	$tables = join(',', @{ $client_data->get_vesioned_table_names() });
    }

	my $last_initial_version_id = $client_data->get_last_initial_version_id();
    $logger->printf("last initial_version_id [%d]", $last_initial_version_id);
    for my $table (split(',', $tables)) {
    	$output->print_sql("DELETE FROM ".$table."_versioned WHERE client_id=".$client_data->get_id().
    		" AND dataset_version_id < ".$last_initial_version_id, $client_data->get_username(), undef, $table);
    }
}

package Output::File;

sub new {
    my ($class, $logger, $output, $batch_size) = @_;

    open(my $fh, ">", $output) or die "can't write [$output]: $!";
	
    return bless {
    	'logger' => $logger,
    	'output' => $output,
    	'batch_size' => sub { $batch_size },
    	'fh' => $fh,
	}, $class;
}

sub print_sql {
    my ($self, $sql, $username, $count, $table) = @_;

	my $fh = $self->{'fh'};
	print $fh "$sql; -- $username\n";
    $self->{'logger'}->register_category("successful delete query in $table");
}

sub start_table {
    my ($self, $table, $version_id, $username) = @_;
	
    return Output::Table->new(
    	$self,
    	$self->{'batch_size'},
    	$table,
    	$version_id, 
    	$username,
	)
}

sub close {
    my ($self) = @_;
	
	close($self->{'fh'});
}

package Output::DB;

use base 'Output::File';

sub new {
    my ($class, $logger, $data_source, $sleep, $batch_size) = @_;

    my $self = bless {
    	'logger' => $logger,
    	'data_source' => $data_source,
    };
    $self->{'sleep'} = $self->_changable_value('sleep', $sleep);
	$self->{'batch_size'} = $self->_changable_value('batch-size', $batch_size);
	return $self;
}


sub print_sql {
    my ($self, $sql, $username, $count, $table) = @_;

    if (defined $count) {
	    $self->{'logger'}->printf_slow("delete old records to [%d] ids", $count);
    }
    eval {
	    $self->{'data_source'}{'dbh'}->do($sql);
	    $self->{'logger'}->register_category("successful delete query in $table");
    };
    if ($@) {
	    $self->{'logger'}->printf("delete from [%s] failed: $!", $table, $@);
	    $self->{'logger'}->register_category("failed delete query in $table");
    }
    sleep($self->{'sleep'}->());
}

sub close {
    my ($self) = @_;
	
}

sub _changable_value {
    my ($self, $name, $value) = @_;
	
	if ($value =~ m{^file:(.+)}) {
		my $file = $1;
		my $last_value = $self->_read_number($name, $file);
		unless (defined $last_value) {
			die "can't read parameter [$name] from [$file]";
		}
		return sub {
			my $value = $self->_read_number($name, $file);
			if (defined $value) {
				if ($value != $last_value) {
					$last_value = $value;
					$self->{'logger'}->printf("new value of [%s]: %s", $name, $last_value);
				}
			}
			return $last_value;
		}
	} else {
		return sub {
			$value
		};
	}
}

sub _read_number {
	my ($self, $name, $file) = @_;

	if (open(my $fh, "<", $file)) {
		my $value = int(<$fh>);
		CORE::close($fh);
		return $value;
	} else {
		$self->{'logger'}->printf("can't read parameter [%s] from [%s]: %s", $name, $file, $!);
		return undef;
	}
}

package Output::Table;

sub new {
	my ($class, $output, $batch_size, $table, $version_id, $username) = @_;
	
	return bless {
		'batch_size' => $batch_size,
		'ids' => [],
		'output' => $output,
		'table' => $table,
		'version_id' => $version_id,
		'username' => $username,
	}, $class;
}

sub detete_id {
    my ($self, $id, ) = @_;

    push(@{ $self->{'ids'} }, $id);

    my $batch_size = $self->{'batch_size'}->();
    if (@{ $self->{'ids'} } >= $batch_size) {
    	$self->flush();
    	if ($batch_size == 0) {
    		sleep(1);
    	}
    }
}

sub flush {
    my ($self) = @_;
	
	if (@{ $self->{'ids'} }) {
		$self->{'output'}->print_sql("DELETE FROM ".$self->{'table'}."_versioned WHERE id IN (".join(', ', @{ $self->{'ids'} }).
			") AND dataset_version_id < ".$self->{'version_id'}, $self->{'username'}, scalar @{ $self->{'ids'}}, $self->{'table'});
		$self->{'ids'} = [];
	}
}

1;