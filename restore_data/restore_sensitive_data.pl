#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use XML::LibXML;

use lib '../lib';

use DataSource::DB;

my ($username, $xml_file, $db_connection_string) = @ARGV;
if ($xml_file) {
	my $data_source = DataSource::DB->new(undef, $db_connection_string);
	my $client_data = $data_source->get_client_data_by_db($username);
	print "load sensitive data from [$xml_file]\n";
	my $sensitive_tables = get_sensitive_data_from_xml($xml_file);
	for my $table (@$sensitive_tables) {
		print "process table [".$table->{'name'}."]\n";
		$client_data->dump_table_data(@$table{'name', 'id', 'columns', 'where'});
	}
	my $fn = '_'.$username.'.sensitive_data.sql';
	print "write result to [$fn]\n";
	$data_source->save_sql_commands_to_file($fn);
}
else {
	print "Usage: $0 <username> <xml_file> [db_connection_string]\n";
	exit(1);
}

sub get_sensitive_data_from_xml {
	my ($xml_file) = @_;


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
				unless (exists $table{$table_name}{'columns'}{$column}) {
					#print "sensitive column: $table_name.$column\n";
					$table{$table_name}{'columns'}{$column} = 1;
				}
			}
		}
		unless (exists $table{$table_name}{'id'}) {
			my $id_column_nodes = $class_xpath->findnodes('exigen:property[@name="ID"]');
			if ($id_column_nodes->size() == 1) {
				$table{$table_name}{'id'} = $id_column_nodes->get_node(0)->getAttribute("column");
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
	my @tables =
		grep {defined $_->{'id'} && @{ $_->{'columns'} }}
		map {
			{
				'name' => $table{$_}{'table_name'},
				'id' => $table{$_}{'id'},
				'where' => $table{$_}{'where'},
				'columns' => [ sort keys %{ $table{$_}{'columns'} } ],
			}
		} keys %table;
	## skip all foreign keys
	for my $table (@tables) {
		$table->{'columns'} = [ grep {$_ !~ m/_id$/} @{ $table->{'columns'} } ];
	}

#	for my $table (@tables) {
#		printf(
#			"sensitive data [%s.%s]: %s\n",
#			$table->{'name'},
#			$table->{'id'},
#			join(', ', @{ $table->{'columns'} }),
#		);
#	}
	return \@tables;
}

