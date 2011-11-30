#!/usr/bin/perl
## $Id$

use strict;
use warnings;
use feature ':5.10';

use Getopt::Long;
use XML::LibXML;

use lib '../lib';

use DataSource::DB;
use Logger;
use Script;

my ($username, $xml_file, $only_table, $db_connection_string, $skip_passwords);
GetOptions(
	'only-table=s@'  => \$only_table,
	'mapping-file=s'  => \$xml_file,
	'db-connection=s' => \$db_connection_string,
	'skip-passwords!' => \$skip_passwords,
);
$username //= $ARGV[0];
$xml_file //= $ARGV[1];
$db_connection_string //= $ARGV[2];

if ($xml_file) {
	my $logger = Logger->new();

	$logger->printf("load sensitive data from [%s]", $xml_file);
	my $sensitive_tables = get_sensitive_data_from_xml($logger, $xml_file);
	if (defined $only_table && @$only_table) {
		my %filter_tables = map {$_ => 1} @$only_table;
		$logger->printf(
			"restore [%s] table%s only",
			join(', ', @$only_table),
			( @$only_table == 1 ? '' : 's' ),
		);
		$sensitive_tables = [ grep { exists $filter_tables{ $_->{'name'} } } @$sensitive_tables ];
	}
	print_table_restore_rules($logger, $sensitive_tables);

	my ($client_username, $data_source) = Script->choose_data_source_by_username($username, $db_connection_string);
	my $client_data = $data_source->get_client_data_by_db($client_username);
	if ($skip_passwords) {
		$logger->printf("skip passwords");
		for my $table (@$sensitive_tables) {
			$table->{'columns'} = [ grep {$_ ne 'password'} @{ $table->{'columns'} } ];
		}
	}
	$logger->printf(
		"restore data for %s [%s] (%s)",
		$client_data->get_full_type(),
		$client_data->get_username(),
		$data_source->get_connection_info(),
	);
	for my $table (@$sensitive_tables) {
		$logger->printf("process table [%s]", $table->{'name'});
		$client_data->dump_table_data(@$table{'name', 'id', 'columns', 'where'}, $logger);
	}
	my $fn = '_sensitive_data.'.$client_username.'.sql';
	$logger->printf("write result to [%s]", $fn);
	$data_source->save_sql_commands_to_file($fn);
	$logger->print_category_stat();
}
else {
	print <<USAGE;
Usage: $0 <username> [mapping-file] [db_connection_string] [options...]
    --mapping-file=<file_name>
    --db-connection=<db_user:db_password\@db_host:db_port/db_name>
    --skip-passwords - do not restore passwords
    --single-table=<table_name> - restore only speified table
USAGE
	exit(1);
}

sub get_sensitive_data_from_xml {
	my ($logger, $xml_file) = @_;


	my $exigen_ns = "http://mapping.filling.sesame.exigen.com";

	my $parser = XML::LibXML->new();
	my $dom = $parser->parse_file($xml_file);

	my $xpc = XML::LibXML::XPathContext->new($dom);
	$xpc->registerNs("exigen", $exigen_ns);
	my $class_nodes = $xpc->findnodes("//exigen:class");

	my %table;
	for my $class_node ($class_nodes->get_nodelist()) {
		#print "parse [".$class_node->getAttribute('name')."]\n";
		my $table_name = $class_node->getAttribute("name");

		my $class_xpath = XML::LibXML::XPathContext->new($class_node);
		$class_xpath->registerNs("exigen", $exigen_ns);
		my $property_nodes = $class_xpath->findnodes('exigen:additionalProperties/exigen:property');
		for my $property_node ($property_nodes->get_nodelist()) {
			my $skip = $property_node->getAttribute("skipStoring") || 'false';
			if ($skip ne 'true') {
				my $column = $property_node->getAttribute("column");
				my $table_id = get_table_id($class_node, $exigen_ns);
				if (defined $table_id) {
					if (exists $table{$table_name}{'columns'}{$column}) {
						$logger->printf("dumplicated sensitive column: %s.%s", $table_name, $column);
					}
					else {
						#print "sensitive column: $table_name.$column\n";
						$table{$table_name}{'columns'}{$column} = $table_id;
					}
				}
			}
		}
		unless (exists $table{$table_name}{'table_name'}) {
			$table{$table_name}{'table_name'} = $class_node->getAttribute("table");
		}
		if ($table_name eq 'Responsible') {
			$table{$table_name}{'where'} = "type='responsible'";
		}
		if ($table_name eq 'Patient') {
			$table{$table_name}{'where'} = "type='patient'";
		}
	}
	my @tables;
	for my $table (values %table) {
		if (exists $table->{'columns'} && keys %{ $table->{'columns'} }) {
			my $columns_by_id = group_columns_by_id($table->{'columns'});
			for my $table_id (keys %$columns_by_id) {
				push(
					@tables,
					{
						'name' => $table->{'table_name'},
						'where' => $table->{'where'},
						'id' => $table_id,
						'columns' => [ sort @{ $columns_by_id->{$table_id} } ],
					}
				);
			}
		}
	}
	## skip all foreign keys
	for my $table (@tables) {
		$table->{'effective_id'} = sprintf(
			"%s %s and %s %s",
			$table->{'name'},
			$table->{'id'},
			($table->{'where'} // '1'),
			join(", ", @{ $table->{'columns'} }),
		);
		$table->{'columns'} = [ grep {$_ !~ m/_id$/} @{ $table->{'columns'} } ];
	}
	my %unique_rules;
	@tables = grep {! $unique_rules{ $_->{'effective_id'} } ++ } @tables;

	return \@tables;
}

sub group_columns_by_id {
	my ($columns) = @_;

	my %column_by_id;
	for my $column (keys %$columns) {
		push(
			@{ $column_by_id{ $columns->{$column} } },
			$column,
		);
	}
	return \%column_by_id;
}

sub print_table_restore_rules {
	my ($logger, $tables) = @_;

	for my $table (@$tables) {
		$logger->printf(
			"update [%s] where [%s=?%s] set [%s]",
			$table->{'name'},
			$table->{'id'},
			( defined $table->{'where'} ? ' and '.$table->{'where'} : '' ),
			join(', ', @{ $table->{'columns'} }),
		);
	}
}

sub get_table_id {
	my ($class_node, $exigen_ns) = @_;

	my $table_name = $class_node->getAttribute("table");
	my $class_xpath = XML::LibXML::XPathContext->new($class_node);
	$class_xpath->registerNs("exigen", $exigen_ns);

	my $id_column_nodes = $class_xpath->findnodes('exigen:property[@name="ID"]');
	if ($id_column_nodes->size() == 1) {
		return $id_column_nodes->get_node(0)->getAttribute("column");
	}
	else {
		my $key_column_nodes = $class_xpath->findnodes('exigen:key/exigen:property[@name="ID" and @column!="client_id"]');
		if ($key_column_nodes->size() == 1) {
			return $key_column_nodes->get_node(0)->getAttribute("column");
		}
		else {
			return undef;
		}
	}
}