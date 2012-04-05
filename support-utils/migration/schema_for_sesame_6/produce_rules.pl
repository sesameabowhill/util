#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';

use JSON;
use File::Slurp;
use Tie::IxHash;

use lib '../../lib';

use Logger;
use Sesame::DB;
use PDMParser;

{
	my $logger = Logger->new();
	my $schema_6 = get_sesame_6_schema($logger);
	my $schema_5 = get_sesame_5_schema($logger, "sesame_5_schema.json");
	my $required_tables = get_required_tables($logger, "_table_migration.json");
	my $links = get_links_from_model($logger, "Unified DB.pdm");
	my $rules = get_schema_diff($logger, $schema_5, $schema_6, $required_tables, $links);
}

sub get_schema_diff {
    my ($logger, $schema_5_list, $schema_6_list, $required_tables, $links) = @_;

	my $schema_5 = group_by_columns($schema_5_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);
	my $schema_6 = group_by_columns($schema_6_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);

    my $migration = Migration->new($schema_6);
    $required_tables = filter_and_expand_required_tables($logger, $required_tables, $migration, ['1', '2', '3']);

	check_removed_tables($logger, $migration, $schema_5, $schema_6);
	my $required = group_by_columns($required_tables, [ 'table' ]);
	tie my %column_rules, "Tie::IxHash";
	for my $table_6 (@$schema_6_list) {
		if (exists $required->{ $table_6->{'TABLE_NAME'} }) {
			$column_rules{ $table_6->{'TABLE_NAME'} }{ $table_6->{'COLUMN_NAME'} } = undef;
		} else {
			#$logger->printf("skip [%s] table", $table_6->{'TABLE_NAME'});
		}
	}
	apply_moved_tables($logger, \%column_rules, $migration, $schema_5_list, $schema_6);
	for_each_undefinded_rule(\%column_rules, $migration, \&get_pms_rule);

	write_file("_out.json", to_json(flat_rules(\%column_rules), { "pretty" => 1 }));

	check_column_rules($logger, \%column_rules);
	return flat_rules(\%column_rules);
}

sub flat_rules {
    my ($column_rules) = @_;

    tie my %rules_by_table, "Tie::IxHash";
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			my $rule = $column_rules->{$table_6}{$column_6};
			if (defined $rule) {
				## skip rule if table name didn't change
				next if $rule->isa('Migration::Rule::MoveValue');
				if (defined $rule->as_json()) {
					tie my %r, "Tie::IxHash", (
						'table' => $table_6,
						'column' => $column_6,
						%{ $rule->as_json() },
					);
					push(
						@{ $rules_by_table{$table_6} },
						\%r
					);
				}
			}
		}
	}
	return \%rules_by_table;
}

sub for_each_undefinded_rule {
    my ($column_rules, $migration, $sub) = @_;
	
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			unless (defined $column_rules->{$table_6}{$column_6}) {
				$column_rules->{$table_6}{$column_6} = $sub->($migration, $table_6, $column_6);
			}
		}
	}
}

sub get_pms_rule {
    my ($migration, $table_6, $column_6) = @_;

    if ($migration->is_column_from_pms($table_6, $column_6)) {
    	return Migration::Rule::FromPMS->new();
	} else {
		return undef;
	}
}

sub apply_moved_tables {
    my ($logger, $column_rules, $migration, $schema_5_list, $schema_6) = @_;

	for my $column (@$schema_5_list) {
		my $new_names = $migration->get_new_names($column->{'TABLE_NAME'});
		for my $new_name (@$new_names) {
			if (exists $column_rules->{$new_name}) {
				if (exists $column_rules->{$new_name}{ $column->{'COLUMN_NAME'} } && 
					! defined $column_rules->{$new_name}{ $column->{'COLUMN_NAME'} }
				) {
					if (can_copy_type($column, $schema_6->{$new_name}{ $column->{'COLUMN_NAME'} })) {
						if ($new_name eq $column->{'TABLE_NAME'}) {
							$column_rules->{$new_name}{ $column->{'COLUMN_NAME'} } = Migration::Rule::MoveValue->new(
								$column->{'TABLE_NAME'}, 
								$column->{'COLUMN_NAME'}
							);
						} else {
							$column_rules->{$new_name}{ $column->{'COLUMN_NAME'} } = Migration::Rule::CopyValue->new(
								$column->{'TABLE_NAME'}, 
								$column->{'COLUMN_NAME'}
							);
						}
					}
				}
			}
		}
	}
}

sub can_copy_type {
    my ($from_column, $to_column) = @_;

    ## TODO
	
	return 1;
}

sub check_column_rules {
	my ($logger, $column_rules) = @_;

	my $stop = 0;
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			unless (defined $column_rules->{$table_6}{$column_6}) {
				$logger->printf("missing rule for [%s.%s]", $table_6, $column_6);
				$stop ++;
			}
		}
	}
	stop($logger, $stop, "missing column rules");
}

sub check_removed_tables {
	my ($logger, $migration, $schema_5, $schema_6) = @_;

	my $stop = 0;
	for my $table_5 (keys %$schema_5) {
		unless ($migration->table_removed($table_5)) {
			unless (exists $schema_6->{ $migration->table_name_after_renamed($table_5) }) {
				$logger->printf("removed table [%s]", $table_5);
				$stop ++;
			}
		}
	}
	stop($logger, $stop, "removed tables found");
}

sub stop {
    my ($logger, $stop, $message_failed) = @_;
	
	if ($stop) {
		$logger->printf("STOP: %s (%d)", $message_failed, $stop);
		exit(1);
	} else {
		$logger->printf("no %s", $message_failed);
	}
}


sub group_by_columns {
    my ($rows, $columns) = @_;
	
	tie my %r, 'Tie::IxHash';
	for my $row (@$rows) {
		_group_by_column(\%r, $row, $columns, []);
	}
	return \%r;
}

sub _group_by_column {
    my ($result, $row, $columns, $path) = @_;

    if (@$columns == 1) {
		my $column = $columns->[0];

    	if (exists $result->{ $row->{$column} } ) {
    		die "duplicated key [".join(".", @$path, $row->{$column})."]";
		} else {
			$result->{ $row->{$column} } = { %$row };
		}
	} else {
		my @left_columns = @$columns;
		my $column = shift @left_columns;
    	unless (exists $result->{ $row->{$column} }) {
    		tie my %n, 'Tie::IxHash';
    		$result->{ $row->{$column} } = \%n;
    	}
		_group_by_column(
			$result->{ $row->{$column} }, 
			$row, 
			\@left_columns,
			[ @$path, $row->{$column} ],
		);
    }
}

sub get_sesame_5_schema {
    my ($logger, $fn) = @_;
	
    $logger->printf("read sesame_5 schema from [%s]", $fn);
    return from_json(read_file($fn));
}

sub get_required_tables {
    my ($logger, $fn, $levels) = @_;
	
    $logger->printf("read required tables from [%s]", $fn);
    return from_json(read_file($fn));
}

sub filter_and_expand_required_tables {
    my ($logger, $tables, $migration, $levels) = @_;

    my @tables_5 = grep { $_->{'priority'} ~~ @$levels } @$tables;
    tie my %tables_6, "Tie::IxHash";
    for my $table (@tables_5) {
    	for my $new_name (@{ $migration->get_new_names( $table->{'table'} ) }) {
			$tables_6{$new_name} = {
				%$table,
				'table' => $new_name,
			};
    	}
    }
    $logger->printf(
    	"[%d] required tables after filtering (priorit%s %s)", 
    	scalar keys %tables_6,
    	(@$levels == 1 ? "y" : "ies"),
    	join(', ', @$levels)
	);
    return [ values %tables_6 ];
}

sub get_sesame_6_schema {
	my ($logger) = @_;

	my $dbh = Sesame::DB->get_main_connection();
	my $database = $dbh->selectrow_array("SELECT DATABASE()");
	$logger->printf("load sesame_6 schema from [%s] database", $database);
	
	return $dbh->selectall_arrayref(
		"SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=? AND ".
		"NOT TABLE_NAME IN (SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA=?)",
		{ 'Slice' => {} },
		$database,
		$database,
	);
}

sub get_links_from_model {
    my ($logger, $fn) = @_;

	$logger->printf("read links from [%s]", $fn);
	my $parser = PDMParser->new($fn);
	my $tables = $parser->get_tables();
	return $parser->get_references();
}


package Migration;

sub new {
    my ($class, $schema_6) = @_;
	
	my $self = bless {
		'removed' => {
			map {$_ => 1} (
			'si_image_old', 'phone_sms_active_from_upload', 'phone_temp',
			'upload_last' ## removed by Dan
			) },
		'renamed' => {
			'appointment_extension' => 'appointment_versioned',
			'email_sent_mail_log_archive' => 'email_sent_mail_log',
			'voice_office_name_pronunciation' => 'office_user_sensitive',
			'patient_pages_message' => 'patient_page_messages',
		},
	}, $class;
	$self->_generate_versioned_rules($schema_6);
	return $self;
}

sub _generate_versioned_rules {
    my ($self, $schema_6) = @_;

    my %versioned;
    for my $table (keys %$schema_6) {
    	my $base_name = $self->_get_versioned_name_base($table);
    	if (defined $base_name) {
    		my @new_tables = grep { exists $schema_6->{$_} } map {$base_name.$_} ('_versioned', '_user_sensitive', '_local');
    		$versioned{$base_name} = \@new_tables;
    	}
    }
    $self->{'versioned'} = \%versioned;
}

sub _get_versioned_name_base {
    my ($self, $name) = @_;
	
	if ($name =~ m{^(.*)_versioned$}) {
		return $1;
	} else {
		return undef;
	}
}

sub table_removed {
    my ($self, $table_5) = @_;

    return exists $self->{'removed'}{$table_5};
}

sub table_name_after_renamed {
    my ($self, $table_5) = @_;

    return $self->get_new_names($table_5)->[0];
}

sub get_new_names {
    my ($self, $table_5) = @_;
	
    if (exists $self->{'renamed'}{$table_5}) {
    	return [ $self->{'renamed'}{$table_5} ];
    } elsif (exists $self->{'versioned'}{$table_5}) {
    	return [ @{ $self->{'versioned'}{$table_5} } ];
    } else {
    	return [ $table_5 ];
    }
}

sub is_column_from_pms {
    my ($self, $table_6, $column_6) = @_;
	
    return defined $self->_get_versioned_name_base($table_6);
}

package Migration::Rule;

sub new {
	my ($class) = @_;
	
	my $self = bless {
	}, $class;
	return $self;
}

sub as_string {
    my ($self) = @_;
	
	die "must override";
}

sub as_json {
    my ($self) = @_;
	
	die "must override";
}

package Migration::Rule::CopyValue;

use base qw(Migration::Rule);

sub new {
	my ($class, $table, $column) = @_;
	
	my $self = bless {
		'table' => $table,
		'column' => $column,
	}, $class;
	return $self;
}

sub as_string {
    my ($self) = @_;
	
	return "value from [".$self->{'table'}.".".$self->{'column'}."]";
}

sub as_json {
    my ($self) = @_;

    tie my %r, "Tie::IxHash", (
    	"action" => "copy",
    	"from_table" => $self->{'table'},
    	"from_column" => $self->{'column'},
    );
	return \%r;
}

package Migration::Rule::MoveValue;

use base qw(Migration::Rule::CopyValue);

package Migration::Rule::FromPMS;

use base qw(Migration::Rule);

sub as_string {
    my ($self) = @_;
	
	return "value from PMS";
}

sub as_json {
    my ($self) = @_;
	
	return undef;
}

1;
