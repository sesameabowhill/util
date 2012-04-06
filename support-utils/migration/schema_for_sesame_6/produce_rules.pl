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
	my $logger = Logger::Migration->new();
	my $required_tables = get_required_tables($logger, "_table_migration.json");

	my $schema_6 = get_sesame_6_schema($logger);
	my $schema_5 = get_sesame_5_schema($logger, "sesame_5_schema.json");

	my $links = Links->new();
	load_links_from_model($logger, $links, "Unified DB.pdm");
	my $rules = get_schema_diff($logger, $schema_5, $schema_6, $required_tables, $links);
}

sub get_schema_diff {
    my ($logger, $schema_5_list, $schema_6_list, $required_tables, $links) = @_;

	my $schema_5 = group_by_columns($schema_5_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);
	my $schema_6 = group_by_columns($schema_6_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);

    my $migration = Migration->new($schema_6, $required_tables);
    $required_tables = filter_and_expand_required_tables($logger, $required_tables, $migration, ['1', '2', '3']);

    $links->rename_tables($migration);
	$links->remove_link_not_from_tables([ map { $_->{'table'} } @$required_tables ], $migration);
	verify_links($logger, $links, $schema_6);

	check_removed_tables($logger, $migration, $schema_5, $schema_6);
	my $required = group_by_columns($required_tables, [ 'table' ]);

	my $rules = MigrationRules->new($logger, $schema_6_list, $required);

	$rules->apply_table_info($migration);
	$rules->apply_simple_columns_info($migration);
	$rules->apply_moved_tables($migration, $schema_5_list, $schema_6);
	
	$rules->save_json_to("_out.json");
	$rules->save_html_to("_out.html");


	$rules->check_column_rules();
	return $rules->flat_rules();
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
	$logger->stop($stop, "removed tables found");
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

sub verify_links {
    my ($logger, $links, $schema_6) = @_;
	
	my $stop = 0;
	for my $column (@$schema_6) {
		if ($column->{'COLUMN_NAME'} =~ m{^(.*)_id$} && ! ( $column->{'COLUMN_NAME'} ~~ ['pms_id', 'link_id'] ) ) {
			my $to_table = $1;
			unless (
				$links->is_link_exists_from_column_to_table(
					$column->{'TABLE_NAME'}, 
					$column->{'COLUMN_NAME'},
					$to_table,
				)
			) {
				$logger->printf("link for [".$column->{'TABLE_NAME'}.".".$column->{'COLUMN_NAME'}."] is not found");
				$stop ++;
			}
		}
	}
	$logger->stop($stop, "missing links");
}

sub load_links_from_model {
    my ($logger, $links, $fn) = @_;

	$logger->printf("read links from [%s]", $fn);
	my $parser = PDMParser->new($fn);
	my $tables = $parser->get_tables();

# 0  HASH(0x8ab9138)
#   'o1000' => HASH(0x8c59df0)
#      'attributes' => HASH(0x995adb0)
#           empty hash
#      'columns' => HASH(0x8c595a0)
#         'o1392' => HASH(0x8c54548)
#            'name' => 'hdl_id'
#      'name' => 'holiday_settings'

# 0  HASH(0x8a64e80)
#    'o103' => HASH(0x9b39248)
#       'from' => HASH(0x9af2730)
#          'column_id' => 'o1702'
#          'table_id' => 'o1031'
#       'to' => HASH(0x89506f0)
#          'column_id' => 'o1697'
#          'table_id' => 'o1030'

	my $references = $parser->get_references();
	for my $reference (values %$references) {
		$links->add_link(
			$tables->{ $reference->{'from'}{'table_id'} }{'name'},
			$tables->{ $reference->{'to'}{'table_id'} }{'name'},
			{
				$tables->{ $reference->{'from'}{'table_id'} }{'columns'}{ $reference->{'from'}{'column_id'} }{'name'} =>
				$tables->{ $reference->{'to'}{'table_id'} }{'columns'}{ $reference->{'to'}{'column_id'} }{'name'}
			}
		);
	}
}


package MigrationRules;

use JSON;
use File::Slurp;

sub new {
	my ($class, $logger, $schema_6_list, $required) = @_;
	
	tie my %column_rules, "Tie::IxHash";
	for my $table_6 (@$schema_6_list) {
		if (exists $required->{ $table_6->{'TABLE_NAME'} }) {
			$column_rules{ $table_6->{'TABLE_NAME'} }{ $table_6->{'COLUMN_NAME'} } = undef;
		} else {
			#$logger->printf("skip [%s] table", $table_6->{'TABLE_NAME'});
		}
	}

	my $self = bless {
		'logger' => $logger,
		'rules' => \%column_rules,
		'tables' => {},
		'column_order' => {
			'id' => -2,
			'client_id' => -1,
		},
	}, $class;
	return $self;
}

sub apply_table_info {
    my ($self, $migration) = @_;
	
	for my $table (keys %{ $self->{'rules'} }) {
		$self->{'tables'}{$table} = {
			"action" => $migration->get_table_action($table),
		};
	}
}

sub flat_rules {
    my ($self) = @_;

    my $column_rules = $self->{'rules'};

    tie my %rules_by_table, "Tie::IxHash";
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			my $rule = $column_rules->{$table_6}{$column_6};
			if (defined $rule) {
				if (defined $rule->as_json()) {
					unless (exists $rules_by_table{$table_6}) {
						$rules_by_table{$table_6} = {
							(exists $self->{'tables'}{$table_6} ? %{ $self->{'tables'}{$table_6} } : () ),
							'columns' => [],
						};
					}
					tie my %r, "Tie::IxHash", (
						'table' => $table_6,
						'column' => $column_6,
						'comment' => $rule->as_string(),
						'_ref' => ref $rule,
						%{ $rule->as_json() },
					);
					push(
						@{ $rules_by_table{$table_6}{'columns'} },
						\%r
					);
				}
			}
		}
	}
	return \%rules_by_table;
}

sub save_json_to {
    my ($self, $fn) = @_;
	
    $self->{'logger'}->printf("save rules as json to [%s]", $fn);
	write_file($fn, to_json($self->flat_rules(), { "pretty" => 1 }));
}

sub save_html_to {
    my ($self, $fn) = @_;
	
    $self->{'logger'}->printf("save rules as html to [%s]", $fn);
    my $rules = $self->flat_rules();
    my @lines = (
    	"<html><head><style>",
    	"body {font-family: Verdana, Arial, Helvetica; }",
    	"table {border: 1px solid #ccc; border-collapse:collapse; font-size: 9pt;}",
    	"td, th {border-top: 1px solid #ccc; border-left: 1px dashed #ccc; padding-left: 0.5em; padding-right: 0.5em;}",
    	#".highlight { color: #49717F }",
    	".nohighlight { color: #999 }",
    	"th {text-align: left; }",
    	"</style></head><body>");
    for my $table (keys %$rules) {
    	push(@lines, "<h2>Table [$table]</h2>");
    	push(@lines, "<p>Action: ".$rules->{$table}{'action'}."</p>");
    	push(@lines, "<table><tr><th>column</th><th>from</th><th>description</th></tr>");
    	for my $column ($self->_sort_column_names( $rules->{$table}{'columns'} ) ) {
	    	push(@lines, "<tr><td>".$column->{'column'}."</td>");
	    	push(
    			@lines, 
    			"<td>".( $column->{'from_table'} ? 
    				_html_highlight($column->{'from_table'}, $column->{'from_table'} ne $column->{'table'}) . "." . 
    				_html_highlight($column->{'from_column'}, $column->{'from_column'} ne $column->{'column'}) :
    				""
				)."</td>"
			);
    		push(@lines, "<td>"._html_highlight($column->{'comment'}, $column->{'_ref'} !~ m{(?:Copy|Move)Value}) ."</td></tr>");
    	}
    	push(@lines, "</table>");
    }

	push(@lines, "</body></html>");

	write_file($fn, join("\n", @lines));
}

sub _sort_column_names {
    my ($self, $names) = @_;
	
	return 
		map {$_->[0]}
		sort { ($self->{'column_order'}{$a->[1]} // 0) <=> ($self->{'column_order'}{$b->[1]} // 0) || $a->[1] cmp $b->[1] } 
		map { [$_, $_->{'column'}] }@$names;
}

sub _html_highlight {
	my ($value, $condition) = @_;

	if ($condition) {
		return "<span class=\"highlight\">$value</span>";
	} else {
		return "<span class=\"nohighlight\">$value</span>";
	}
}

sub _for_each_undefinded_rule {
    my ($self, $sub) = @_;

    my $column_rules = $self->{'rules'};
	
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			unless (defined $column_rules->{$table_6}{$column_6}) {
				$column_rules->{$table_6}{$column_6} = $sub->($table_6, $column_6);
			}
		}
	}
}

sub apply_simple_columns_info {
    my ($self, $migration) = @_;
	
    $self->_for_each_undefinded_rule(
		sub {
		    my ($table_6, $column_6) = @_;

		    if ($migration->is_column_from_pms($table_6, $column_6)) {
		    	return Migration::Rule::FromPMS->new();
		    } elsif ($migration->is_column_autoincrement($table_6, $column_6)) {
		    	return Migration::Rule::AutoIncrement->new();
			} else {
				my $hardcoded_lookup = $migration->get_hardcoded_lookup($table_6, $column_6);
				if (defined $hardcoded_lookup) {
					return Migration::Rule::HardCodedMap->new($hardcoded_lookup);
				} else {
					return undef;
				}
			}
		}
	);
}

sub apply_moved_tables {
    my ($self, $migration, $schema_5_list, $schema_6) = @_;

    my $column_rules = $self->{'rules'};

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
	my ($self) = @_;

	my $column_rules = $self->{'rules'};

	my $stop = 0;
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			unless (defined $column_rules->{$table_6}{$column_6}) {
				$self->{'logger'}->printf("missing rule for [%s.%s]", $table_6, $column_6);
				$stop ++;
			}
		}
	}
	$self->{'logger'}->stop($stop, "missing column rules");
}


package Logger::Migration;

use base 'Logger';

sub stop {
    my ($self, $stop, $message_failed) = @_;
	
	if ($stop) {
		$self->printf("STOP: %s (%d)", $message_failed, $stop);
		exit(1);
	} else {
		$self->printf("no %s", $message_failed);
	}
}

package Links;

sub new {
	my ($class) = @_;
	
	my $self = bless {
		'links' => {},
	}, $class;
	return $self;
}

sub add_link {
    my ($self, $from_table, $to_table, $columns) = @_;

    if ($self->is_link_exists($from_table, $to_table, $columns)) {
		die "link [$from_table] -> [$to_table] on [".$self->_columns_to_string($columns)."] is allready defined";
	}
    my $from_columns = join("|", sort keys %$columns);
	$self->{'links'}{$from_table}{$to_table}{$from_columns} = $columns;
}

sub is_link_exists {
    my ($self, $from_table, $to_table, $columns) = @_;

	my $from_columns = join("|", sort keys %$columns);
	return exists $self->{'links'}{$from_table}{$to_table}{$from_columns};
}

sub is_link_exists_from_column_to_table {
    my ($self, $from_table, $from_column, $to_table) = @_;
	
	return exists $self->{'links'}{$from_table}{$to_table}{$from_column};
}

sub remove_link_not_from_tables {
    my ($self, $tables, $migration) = @_;

    my %allowed_tables = map { $_ => 1 } @$tables;
	
	my %deleted_tables;
	for my $from_table (keys %{ $self->{'links'} }) {
		unless ($allowed_tables{$from_table}) {
			$deleted_tables{$from_table} = 1;
			delete $self->{'links'}{$from_table};
		}
	}
	for my $from_table (keys %{ $self->{'links'} }) {
		for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
			if (exists $deleted_tables{$to_table}) {
				for my $from_column_str (keys %{ $self->{'links'}{$from_table}{$to_table} }) {
					unless ($migration->get_hardcoded_lookup($from_table, $from_column_str)) {
						die "table [".$to_table."] was removed, but link is in [".$from_table.".".$from_column_str."]";
					}
				}
			}
		}
	}
}

sub rename_tables {
    my ($self, $migration) = @_;

    my %links;
	for my $from_table (keys %{ $self->{'links'} }) {
		my $new_from_tables = $migration->get_new_names($from_table);
		for my $new_from_table (@$new_from_tables) {
			for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
				my $new_to_table = $migration->table_name_after_renamed($to_table);
				$links{$new_from_table}{$new_to_table} = $self->{'links'}{$from_table}{$to_table};
			}
		}
	}
	$self->{'links'} = \%links;
}

sub _columns_to_string {
    my ($self, $columns) = @_;
	
	return join(" AND ", map { $_."=".$columns->{$_} } sort keys %$columns);
}


package Migration;

sub new {
    my ($class, $schema_6, $required_tables) = @_;
	
	my $self = bless {
		'removed' => {
			map {$_ => 1} (
				'si_image_old', 'phone_sms_active_from_upload', 'phone_temp',
				## pms data tables
				'account', 'appointment_procedure', 'insurance_contract', 'ledger', 
				'patient_referrer', 'patient_staff', 'staff', 
				'treatment_plan', 
				## removed by Dan 
				'upload_last', 
			) 
		},
		'renamed' => {
			'appointment_extension' => 'appointment_versioned',
			'email_sent_mail_log_archive' => 'email_sent_mail_log',
			'voice_office_name_pronunciation' => 'office_user_sensitive',
			'patient_pages_message' => 'patient_page_messages',
			'office' => 'office_user_sensitive', ## TODO need to move fields
			'referrer' => 'referrer_local',
		},
		'hardcoded_lookup' => {
			'survey_answer' => {
				'question_id' => 'survey-question-id',
				'question_option_id' => 'survey-option-id',
			},
		},
	}, $class;
	$self->_generate_versioned_rules($schema_6, $required_tables);
	$self->_generate_actions($required_tables);
	$self->_generate_autoincrement($schema_6);
	return $self;
}

sub _generate_actions {
    my ($self, $required_tables) = @_;
	
	my %know_actions = map {$_ => 1} ('delete-insert', 'insert', 'update', 'update-insert');
	my %actions;
	for my $table (@$required_tables) {
		if ($table->{'action'} eq 'referrer') {
			## TODO
			$actions{$table->{'table'}} = "???";
			$actions{$table->{'table'}."_local"} = "???";
		} elsif ($table->{'action'} eq 'user-sensitive') {
			$actions{$table->{'table'}."_user_sensitive"} = "update";
			$actions{$table->{'table'}."_local"} = "delete-insert";
		} elsif (exists $know_actions{$table->{'action'}}) {
			$actions{ $self->table_name_after_renamed($table->{'table'}) } = $table->{'action'};
		} elsif (!$table->{'action'}) {
			## ignore empty actions
		} else {
			die "unknow action [".$table->{'action'}."]";
		}
	}
	$self->{'actions'} = \%actions;
}

sub _generate_versioned_rules {
    my ($self, $schema_6, $required_tables) = @_;

    my %versioned;
    for my $table (grep {$_->{'transform'} ~~ ['user-sensitive', 'user-sensitive-local', 'local-only']} @$required_tables) {
		my @new_tables = grep { exists $schema_6->{$_} } map {$table->{'table'}.$_} ('_user_sensitive', '_local');
		unless (@new_tables) {
			die "no tables for ".$table->{'transform'}." transform for [".$table->{'table'}."]";
		}
		$versioned{ $table->{'table'} } = \@new_tables;
    }
    $self->{'versioned'} = \%versioned;
}

sub _generate_autoincrement {
    my ($self, $schema_6) = @_;

    my %autoincrement;
    for my $table (keys %$schema_6) {
    	for my $column (keys %{ $schema_6->{$table} }) {
    		if ($schema_6->{$table}{$column}{'EXTRA'} =~ m{auto_increment}i) {
    			$autoincrement{$table}{$column} = 1;
    		}
    	}
    }
    $self->{'autoincrement'} = \%autoincrement;
}

sub is_column_autoincrement {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'autoincrement'}{$table_6}{$column_6};
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

sub get_table_action {
    my ($self, $table_6) = @_;
	
	if (exists $self->{'actions'}{$table_6}) {
		return $self->{'actions'}{$table_6};
	} else {
		die "can't find action for [$table_6]";
	}
}

sub get_hardcoded_lookup {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'hardcoded_lookup'}{$table_6}{$column_6};
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

# sub get_table {
#     my ($self) = @_;
	
# 	return $self->{'table'};
# }

# sub get_column {
#     my ($self) = @_;
	
# 	return $self->{'column'};
# }

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


package Migration::Rule::AutoIncrement;

use base qw(Migration::Rule);

sub as_string {
    my ($self) = @_;
	
	return "auto increment";
}

sub as_json {
    my ($self) = @_;
	
	return {
		"action" => "autoincrement",
	};
}

package Migration::Rule::HardCodedMap;

use base qw(Migration::Rule);

sub new {
	my ($class, $map) = @_;
	
	my $self = bless {
		'map' => $map,
	}, $class;
	return $self;
}

sub as_string {
    my ($self) = @_;
	
	return "hard coded value from [".$self->{'map'}."] map";
}

sub as_json {
    my ($self) = @_;

    tie my %r, "Tie::IxHash", (
    	"action" => "map-lookup",
    	"map" => $self->{'map'},
    );
	return \%r;
}
