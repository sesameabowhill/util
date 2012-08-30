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
	$rules->save_json_to("_rules.json");
}

sub get_schema_diff {
	my ($logger, $schema_5_list, $schema_6_list, $required_tables, $links) = @_;

	my $schema_5 = group_by_columns($schema_5_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);
	my $schema_6 = group_by_columns($schema_6_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);

	my $migration = Migration->new($schema_6, $required_tables);
	$migration->load_hard_coded_links($links);
	$required_tables = filter_and_expand_required_tables($logger, $required_tables, $migration, ['1', '2', '3']);

	$links->rename_tables($migration, $schema_6);
	$migration->restore_remap_only_links($links);
	my %allowed_tables = map { $_->{'table'} => 1 } @$required_tables;
	$links->remove_link_not_from_tables(\%allowed_tables);
	$links->verify_broken_links($logger, \%allowed_tables, $migration);

	verify_links($logger, $links, $schema_6_list, \%allowed_tables, $migration);

	check_removed_tables($logger, $migration, $schema_5, $schema_6);
	my $required = group_by_columns($required_tables, [ 'table' ]);

	my $rules = MigrationRules->new($logger, $schema_6_list, $required, $migration);

	$rules->remove_ignored_columns($migration);
	$rules->make_secondary_rules($migration);
	$rules->apply_simple_columns_info($migration);
	$rules->apply_links($links, $migration);
	$rules->apply_table_info($migration, $links, $schema_6_list);
	$rules->apply_table_priority($migration, $required_tables);
	$rules->apply_moved_tables($migration, $schema_5_list, $schema_6, $links);
	$rules->update_copy_columns_for_link();
	$rules->update_copy_columns_for_eval($migration);
	$rules->apply_missing_eval($migration, $links);
	$rules->make_multiple_tables_rules($migration, $schema_6);
	
	$rules->save_json_to("_out.json", 1);
	$rules->save_html_to("_out.html");
	$rules->save_jira_to("_out.jira");


	$rules->check_column_rules();
	return $rules;
}

sub check_removed_tables {
	my ($logger, $migration, $schema_5, $schema_6) = @_;

	my $stop = 0;
	for my $table_5 (keys %$schema_5) {
		if ($migration->table_removed($table_5)) {
			## skip removed tables
		}  elsif ($migration->is_table_versioned($table_5)) {
			## skip versioned tables
		} else {
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

	tie my %tables_6, "Tie::IxHash";
	for my $table (@$tables) {
		if ($table->{'priority'} ~~ @$levels) {
			for my $new_name (@{ $migration->get_new_names( $table->{'table'} ) }) {
				$tables_6{$new_name} = {
					%$table,
					'table' => $new_name,
				};
			}
			#$logger->printf("include [%s] table", $table->{'table'});
		} else {
			#$logger->printf("table [%s] is ignored", $table->{'table'});
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
	my ($logger, $links, $schema_6, $allowed_tables, $migration) = @_;
	
	my %not_link = map { $_ => 1 } (
		"*.pms_id", "*.link_id", "*.voice_queue_id", "*.clog_mail_id", "*.sml_mail_id", 
		"*.vip_patient_id", "invisalign_text.page_id", "si_image.is_id", "sms_message_history.client_id", 
		"sms_message_response.client_id" );
	my %to_table = (
		'patient_id' => "visitor",
		'responsible_id' => "visitor",
		'member_id' =>  "client",
	);

	my (%primary_keys, %tables);
	for my $column (@$schema_6) {
		$tables{$column->{'TABLE_NAME'}} = 1;
		if ($column->{'COLUMN_KEY'} eq "PRI") {
			push(@{ $primary_keys{$column->{'TABLE_NAME'}} }, $column->{'COLUMN_NAME'});
		}
	}
	my %simple_primary_keys = map { $_ => { $primary_keys{$_}[0] => 1 } } grep { @{ $primary_keys{$_} } == 1 } keys %primary_keys;

	my $stop = 0;
	for my $column (@$schema_6) {
		if (exists $allowed_tables->{ $column->{'TABLE_NAME'} } && 
			! exists $simple_primary_keys{ $column->{'TABLE_NAME'} }{ $column->{'COLUMN_NAME'} }
		) {
			if ($column->{'COLUMN_NAME'} =~ m{^(.*)_id$} && 
				! exists $not_link{ "*.".$column->{'COLUMN_NAME'} } && 
				! exists $not_link{ $column->{'TABLE_NAME'}.".".$column->{'COLUMN_NAME'} } && 
				! $migration->is_lookup($column->{'TABLE_NAME'}, $column->{'COLUMN_NAME'}) 
			) {
				my $to_table = ( exists $to_table{$column->{'COLUMN_NAME'}} ? $to_table{$column->{'COLUMN_NAME'}} : $1 );
				if (exists $tables{$to_table}) {
					unless (
						$links->is_link_exists_between_tables(
							$column->{'TABLE_NAME'}, 
							$to_table,
						)
					) {
						$logger->printf("link for [".$column->{'TABLE_NAME'}.".".$column->{'COLUMN_NAME'}."] is not found (expecting link to $to_table)");
						$stop ++;
					}
				} else {
					unless (
						$links->is_link_exists_from_column(
							$column->{'TABLE_NAME'}, 
							$column->{'COLUMN_NAME'},
						)
					) {
						$logger->printf("link for [".$column->{'TABLE_NAME'}.".".$column->{'COLUMN_NAME'}."] is not found");
						$stop ++;
					}
				}
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
			},
			"from pdm",
		);
	}
	$links->delete_link_between_tables("email_referral", "referrer");
	$links->delete_link_between_tables("si_pms_referrer_link", "referrer");
	$links->delete_link_between_tables("si_theme", "si_message");
	$links->delete_link_between_tables("ppn_article_letter", "ppn_common_article");
	$links->delete_link_between_tables("sms_message_history", "client");
	$links->delete_link_between_tables("sms_message_response", "client");
	$links->delete_link_between_tables("referrer_email_log", "referrer");
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

	tie my %tables, "Tie::IxHash";
	my $self = bless {
		'logger' => $logger,
		'rules' => \%column_rules,
		'tables' => \%tables,
		'column_order' => {
			'id' => -2,
			'client_id' => -1,
		},
	}, $class;
	return $self;
}

sub make_secondary_rules {
	my ($self, $migration) = @_;

	for my $table_6 (keys %{ $self->{'rules'} }) {
		my $secondary_rules = $migration->get_secondary_rule_names($table_6);
		for my $table_to (@$secondary_rules) {
			$self->{'rules'}{$table_to} = { %{ $self->{'rules'}{$table_6} } };
		}
	}
}

sub remove_ignored_columns {
	my ($self, $migration) = @_;
	
	for my $table_6 (keys %{ $self->{'rules'} }) {
		for my $column_6 (keys %{ $self->{'rules'}{$table_6} }) {
			if ($migration->is_column_ignored($table_6, $column_6)) {
				delete $self->{'rules'}{$table_6}{$column_6};
			}
		}
	}
}

sub apply_table_info {
	my ($self, $migration, $links, $schema_6) = @_;

	$self->{'remap_only_tables'} = $migration->get_tables_with_remap_only_action();

	{
		my %remap_only_tables = map { $_ => 1 } @{ $self->{'remap_only_tables'} };
		my $stop = 0;
		my $update_on_columns = $self->get_update_on_columns($schema_6, $migration);
		for my $table (keys %{ $self->{'rules'} }) {
			if (exists $remap_only_tables{$table}) {
				die "rules found for remap-only table [$table]";
			}
			my $table_action = $migration->get_table_action($table);
			tie my %r, 'Tie::IxHash', (
				'action' => $table_action,
			);
			if ($table_action =~ m{update}) {
				if (exists $update_on_columns->{$table}) {
					$r{'update_on'} = [ @{ $update_on_columns->{$table} } ],
				} else {
					$stop ++ ;
					$self->{'logger'}->printf("can't update [%s]: no keys to use", $table);
				}
			}
			$self->{'tables'}{$table} = \%r;
		}
		$self->{'logger'}->stop($stop, "missing columns to update on");
	}

	{
		my $stop = 0;
		for my $table (keys %{ $self->{'rules'} }) {
			if ($table ne 'client') {
				if (defined $migration->get_path_to_client($table)) {
					$self->{'tables'}{$table}{'path_to_client'} = $migration->get_path_to_client($table);
				} else {
					my $path = $self->find_path_to_client($migration->get_table_name($table), $links);
					if (defined $path) {
						$self->{'tables'}{$table}{'path_to_client'} = $path;
					} else {
						#$stop ++;
						$self->{'logger'}->printf("can't find link from [%s] to client", $table);
					}
				}
			}
		}
		$self->{'logger'}->stop($stop, "tables without link to client");
	}
}

sub apply_table_priority {
	my ($self, $migration, $required_tables) = @_;

	for my $table (@$required_tables) {
		my $new_names = $migration->get_new_names($table->{'table'});
		for my $new_name (@$new_names) {
			if (exists $self->{'tables'}{$new_name}) {
				$self->{'tables'}{$new_name}{'priority'} = $table->{'priority'};
				if ($table->{'priority'} == 3 && $table->{'transform'} eq 'past-week') {
					my $date_column = $migration->get_date_column($new_name);
					unless (defined $date_column) {
						die "no data column for [$new_name]";
					}
					$self->{'tables'}{$new_name}{'priority_two_date_column'} = $date_column;
				}
			}
		}
	}

	my $stop = 0;
	for my $table (keys %{ $self->{'rules'} }) {
		unless (exists $self->{'tables'}{$table}{'priority'}) {
			$stop++;
			$self->{'logger'}->printf("no priority for [%s]", $table);
		}
	}	
	$self->{'logger'}->stop($stop, "tables without priority");
}

sub make_multiple_tables_rules {
	my ($self, $migration, $schema_6) = @_;

	my $stop = 0;
	my $column_rules = $self->{'rules'};
	
	for my $table_6 (keys %$column_rules) {
		my %from_tables;
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			if (ref $column_rules->{$table_6}{$column_6} eq 'Migration::Rule::CopyValue') {
				$from_tables{$column_rules->{$table_6}{$column_6}{'table'}} = 1;
			}
		}
		if (keys %from_tables > 1) {
			$self->{'logger'}->printf("%s rule uses multiple tables: %s", $table_6, join(', ', sort keys %from_tables));
			$stop++;
		}
	}
	##$self->{'logger'}->stop($stop, "tables with multiple source");
}


sub get_update_on_columns {
	my ($self, $schema_6, $migration) = @_;
	
	my (%primary_keys);
	for my $column (@$schema_6) {
		if ($column->{'COLUMN_KEY'} eq "PRI") {
			unless ($column->{'EXTRA'} =~ m{auto_increment}i) {
				push(@{ $primary_keys{$column->{'TABLE_NAME'}} }, $column->{'COLUMN_NAME'});
			}
		}
	}
	for my $column (@$schema_6) {
		my $update_on = $migration->get_update_on_columns($column->{'TABLE_NAME'});
		if (defined $update_on) {
			$primary_keys{$column->{'TABLE_NAME'}} = $update_on;
		}
	}
	return \%primary_keys;
}

sub find_path_to_client {
	my ($self, $table, $links, $depth, $visited) = @_;

	$depth //= 0;
	$visited //= {
		$table => 1,
	};
	my @found_paths;
	if ($links->is_link_exists_between_tables($table, "client")) {
		push(
			@found_paths,
			[
				{
					'table' => $table,
					'column' => $links->get_link_column_between_tables($table, "client"),
				},
			]
		);
	} else {
		$links->for_each_link_from(
			$table,
			sub {
				my ($to_table, $columns) = @_;

				unless (exists $visited->{$to_table}) {
					$visited->{$to_table} = 1;
					my $path = $self->find_path_to_client($to_table, $links, $depth + 1, $visited);
					if (defined $path && 1 == keys %$columns) {
						unshift(
							@$path, 
							{
								'table' => $table,
								'column' => ((keys %$columns)[0]),
							}
						);
						push(@found_paths, $path);
					}
				} 
			}
		);
	}
	## put shortest path on top
	@found_paths = 
		map {$_->[0]}
		sort {$b->[1] <=> $a->[1]} 
		map {[$_, scalar @$_]} @found_paths;
	return $found_paths[0];
}

sub flat_rules {
	my ($self, $no_missing_rules) = @_;

	my $column_rules = $self->{'rules'};

	tie my %rules_by_table, "Tie::IxHash";

	for my $table_6 (@{ $self->{'remap_only_tables'} }) {
		tie my %r, 'Tie::IxHash', (
			'to_table' => _get_table_name($table_6),
			'action' => 'remap-only',
			'columns' => [
				$self->_make_json_column_obj(
					$table_6,
					'id',
					Migration::Rule::CopyValue->new($table_6, 'id'),
					$no_missing_rules,
				),
				$self->_make_json_column_obj(
					$table_6,
					'pms_id',
					Migration::Rule::CopyValue->new($table_6, 'pms_id'),
					$no_missing_rules,
				),
				$self->_make_json_column_obj(
					$table_6,
					'client_id',
					Migration::Rule::Eval->new('client-id', undef, undef),
					$no_missing_rules,
				),
			],
			'path_to_client' => [
				{
					'table' => $table_6,
					'column' => 'client_id',
				}
			],
			'priority' => '1',
		);
		$rules_by_table{$table_6} = \%r;
	}    

	for my $table_6 (keys %$column_rules) {
		my @missing_rules;
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			my $rule = $column_rules->{$table_6}{$column_6};
			if (defined $rule) {
				if (defined $rule->as_json()) {
					unless (exists $rules_by_table{$table_6}) {
						tie my %r, 'Tie::IxHash', (
							'to_table' => _get_table_name($table_6),
							(exists $self->{'tables'}{$table_6} ? %{ $self->{'tables'}{$table_6} } : () ),
							'columns' => [],
						);
						$rules_by_table{$table_6} = \%r;
					}
					my $column = $self->_make_json_column_obj($table_6, $column_6, $rule, $no_missing_rules);
					push(@{ $rules_by_table{$table_6}{'columns'} }, $column);
				}
			} else {
				push(@missing_rules, $column_6);
			}
		}
		if (!$no_missing_rules && @missing_rules) {
			for my $column_6 (@missing_rules) {
				tie my %r, "Tie::IxHash", (
					'table' => $table_6,
					'column' => $column_6,
				);
				push(
					@{ $rules_by_table{$table_6}{'columns'} },
					\%r
				);
			}
		}
	}
	return \%rules_by_table;
}

sub _get_table_name {
	my ($table) = @_;
	
	$table =~ s{:.*$}{};
	return $table;
}

sub _make_json_column_obj {
	my ($self, $table_6, $column_6, $rule, $no_missing_rules) = @_;
	
	tie my %r, "Tie::IxHash", (
		'column' => $column_6,
		'comment' => $rule->as_string(),
		'_ref' => ref $rule,
		($rule->get_source() ? ('_source' => $rule->get_source()) : ()),
		%{ $rule->as_json() },
	);
	unless ($no_missing_rules) {
		for my $debug_key (grep {m{^_}} keys %r) {
			delete $r{$debug_key};
		}
	}
	return \%r;
}

sub save_json_to {
	my ($self, $fn, $no_missing_rules) = @_;
	
	$self->{'logger'}->printf("save rules as json to [%s]", $fn);
	write_file($fn, to_json($self->flat_rules($no_missing_rules), { "pretty" => 1 }));
}

sub save_html_to {
	my ($self, $fn) = @_;
	
	$self->{'logger'}->printf("save rules as html to [%s]", $fn);
	my $rules = $self->flat_rules(1);
	my @lines = (
		"<html><head><style>",
		"body {font-family: Verdana, Arial, Helvetica; }",
		"li {font-size: 11pt;}",
		"table {border: 1px solid #ccc; border-collapse:collapse; font-size: 9pt;}",
		"td, th {border-top: 1px solid #ccc; border-left: 1px dashed #ccc; padding-left: 0.5em; padding-right: 0.5em;}",
		#".highlight { color: #49717F }",
		".nohighlight { color: #999 }",
		".error { color: #f00; font-weight: bold; }",
		"th {text-align: left; }",
		".value {font-weight: bold;}",
		"</style></head><body>");
	for my $table (keys %$rules) {
		push(@lines, "<h2><a name=\"table.".$table."\"></a>Table [$table]</h2>");
		push(@lines, "<ul>");
		push(@lines, "<li>To table: <span class=\"value\">".$rules->{$table}{'to_table'}."</span></li>");
		push(@lines, "<li>Action: <span class=\"value\">".$rules->{$table}{'action'}."</span></li>");
		push(@lines, "<li>Priority: <span class=\"value\">".$rules->{$table}{'priority'}."</span></li>");
		my %update_columns;
		if ($rules->{$table}{'update_on'}) {
			%update_columns = map {$_ => 1} @{ $rules->{$table}{'update_on'} };
			push(@lines, "<li>Update on: ".join(", ", map {"<span class=\"value\">$_</span>"} @{ $rules->{$table}{'update_on'} })."</li>");
		}
		if ($rules->{$table}{'path_to_client'} && @{ $rules->{$table}{'path_to_client'} }) {
			$update_columns{ $rules->{$table}{'path_to_client'}->[0]{'column'} } = 1;
			push(@lines, "<li>Path to client: ".join(" &gt; ", map {"<span class=\"value\">".$_->{'table'}.".".$_->{'column'}."</span>"} @{ $rules->{$table}{'path_to_client'} })."</li>");
		}
		if ($rules->{$table}{'priority_two_date_column'}) {
			$update_columns{$rules->{$table}{'priority_two_date_column'}} = 1;
			push(@lines, "<li>Date column for priority 2 extraction: <span class=\"value\">".$rules->{$table}{'priority_two_date_column'}{'legacy_table'}
				.".".$rules->{$table}{'priority_two_date_column'}{'legacy_column'}."</span></li>");
		}
		push(@lines, "</ul>");
		if (exists $rules->{$table}{'columns'}) {
			push(@lines, "<table><tr><th>column</th><th>from</th><th>action</th></tr>");
			for my $column ($self->_sort_column_names( $rules->{$table}{'columns'} ) ) {
				push(@lines, "<tr><td><a name=\"column.".$rules->{$table}{'to_table'}.".".$column->{'column'}."\"></a>".
					_html_highlight($column->{'column'}, $update_columns{$column->{'column'}}, 'value')."</td>");
				push(
					@lines, 
					"<td>".( $column->{'from_table'} ? 
						_html_highlight($column->{'from_table'}, $column->{'from_table'} ne $rules->{$table}{'to_table'}) . "." . 
						_html_highlight($column->{'from_column'}, $column->{'from_column'} ne $column->{'column'}) :
						""
					)."</td>"
				);
				if (exists $column->{'action'}) {
					if ($column->{'action'} eq "foreign-key") {
						push(@lines, "<td>value from [<a href=\"#table.".$column->{'lookup_table'}."\">".$column->{'lookup_table'}."</a>.".
							"<a href=\"#column.".$column->{'lookup_table'}.".".$column->{'lookup_column'}."\">".$column->{'lookup_column'}.
							"</a>]".(defined $column->{'from_table'} ? " from [".$column->{'from_table'}.".".$column->{'from_column'}."]" : "").
							($column->{'_source'}?" (".$column->{'_source'}.")":"")."</td></tr>");
					} else {
						push(@lines, "<td>"._html_highlight($column->{'comment'}, $column->{'_ref'} !~ m{(?:Copy|Move)Value$})."</td></tr>");
					}
				} else {
					push(@lines, "<td><span class=\"error\">missing</span></td></tr>");
				}
			}
			push(@lines, "</table>");
		} else {
			push(@lines, "<a name=\"column.".$table.".id\"></a>");
		}
	}

	push(@lines, "</body></html>");

	write_file($fn, join("\n", @lines));
}

sub save_jira_to {
	my ($self, $fn) = @_;
	
	$self->{'logger'}->printf("save rules as jira to [%s]", $fn);
	my $rules = $self->flat_rules(1);
	my @lines;
	for my $table (keys %$rules) {
		push(@lines, "h2. Table \\[$table\\]");
		push(@lines, "");
		push(@lines, "* To table: *".$rules->{$table}{'to_table'}."*");
		push(@lines, "* Action: *".$rules->{$table}{'action'}."*");
		push(@lines, "* Priority: *".$rules->{$table}{'priority'}."*");
		my %update_columns;
		if ($rules->{$table}{'update_on'}) {
			%update_columns = map {$_ => 1} @{ $rules->{$table}{'update_on'} };
			push(@lines, "* Update on: ".join(", ", map {"*$_*"} @{ $rules->{$table}{'update_on'} }));
		}
		if ($rules->{$table}{'path_to_client'} && @{ $rules->{$table}{'path_to_client'} }) {
			$update_columns{ $rules->{$table}{'path_to_client'}->[0]{'column'} } = 1;
			push(@lines, "* Path to client: ".join(" > ", map {"*".$_->{'table'}.".".$_->{'column'}."*"} @{ $rules->{$table}{'path_to_client'} }));
		}
		if ($rules->{$table}{'priority_two_date_column'}) {
			$update_columns{$rules->{$table}{'priority_two_date_column'}} = 1;
			push(@lines, "*Date column for priority 2 extraction: *".$rules->{$table}{'priority_two_date_column'}{'legacy_table'}.".".$rules->{$table}{'priority_two_date_column'}{'legacy_column'}."*");
		}
		push(@lines, "");
		if (exists $rules->{$table}{'columns'}) {
			push(@lines, "|| column || from || action ||");
			for my $column ($self->_sort_column_names( $rules->{$table}{'columns'} ) ) {
				my @row;
				push(@row, _jira_highlight($column->{'column'}, $update_columns{$column->{'column'}}));
				push(
					@row, 
					( $column->{'from_table'} ? 
						_jira_nohighlight($column->{'from_table'}, $column->{'from_table'} ne $rules->{$table}{'to_table'}) . "." . 
						_jira_nohighlight($column->{'from_column'}, $column->{'from_column'} ne $column->{'column'}) :
						""
					)
				);
				if (exists $column->{'action'}) {
					if ($column->{'action'} eq "foreign-key") {
						push(@row, "reference to \"".$column->{'lookup_table'}.".".$column->{'lookup_column'}."\"");
					} else {
						$column->{'comment'} =~ s{[\[\]]}{"}g;
						push(@row, _jira_nohighlight($column->{'comment'}, $column->{'_ref'} !~ m{(?:Copy|Move)Value$}));
					}
				} else {
					push(@row, "{color:red}missing{color}");
				}
				push(@lines, "| ".join(" | ", @row)." |");
			}
			push(@lines, "");
		}
	}

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
	my ($value, $condition, $class) = @_;

	$class //= "highlight";

	if ($condition) {
		return "<span class=\"$class\">$value</span>";
	} else {
		return "<span class=\"no$class\">$value</span>";
	}
}

sub _jira_nohighlight {
	my ($value, $condition) = @_;

	if ($condition) {
		return $value;
	} else {
		return "{color:#999999}".$value."{color}";
	}
}

sub _jira_highlight {
	my ($value, $condition) = @_;

	if ($condition) {
		return "*$value*";
	} else {
		return $value;
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

sub _for_each_rule {
	my ($self, $sub) = @_;

	my $column_rules = $self->{'rules'};
	
	for my $table_6 (keys %$column_rules) {
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			my $new_rule = $sub->($table_6, $column_6, $column_rules->{$table_6}{$column_6});
			if (defined $new_rule) {
				$column_rules->{$table_6}{$column_6} = $new_rule;
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
			} 
			if ($migration->is_column_autoincrement($table_6, $column_6)) {
				return Migration::Rule::AutoIncrement->new();
			}
			if ($migration->is_constant_value_exists($table_6, $column_6)) {
				return Migration::Rule::ConstantValue->new($migration->get_constant_value($table_6, $column_6));
			}
			return undef;
		}
	);
}

sub update_copy_columns_for_link {
	my ($self) = @_;

	my %lookups;
	$self->_for_each_rule(
		sub {
		    my ($table_6, $column_6, $rule) = @_;
			
		    if (ref $rule eq 'Migration::Rule::ForeignKey') {
		    	$lookups{ $rule->{'table'} }{ $rule->{'column'} } = 1;
		    }
			return undef;
		}
	);

	$self->_for_each_rule(
		sub {
		    my ($table_6, $column_6, $rule) = @_;
			
			if ($lookups{$table_6}{$column_6}) {
				if (ref $rule eq 'Migration::Rule::CopyValue') {
					$rule->set_copy_and_save();
					$self->{'logger'}->printf("%s.%s <- %s", $table_6, $column_6, $rule->as_string());
				}
			}
			return undef;
		}
	);
}

sub update_copy_columns_for_eval {
    my ($self, $migration) = @_;

    my $stop = 0;
	$self->_for_each_rule(
		sub {
		    my ($table_6, $column_6, $rule) = @_;
			
			if ($migration->get_need_convert_datetime($table_6, $column_6)) {
				if (ref $rule eq 'Migration::Rule::CopyValue') {
					return Migration::Rule::Eval->new(
						'convert-time-zone-from-'.$migration->get_need_convert_datetime($table_6, $column_6), 
						$rule->{'table'},
						$rule->{'column'}
					);
				} else {
					$self->{'logger'}->printf("%s.%s:can't apply datetime convertion to [%s] ", $table_6, $column_6, ref($rule));
					$stop ++;
				}
			}
			return undef;
		}
	);
	$self->{'logger'}->stop($stop, "columns with unexpected rules for time zone convertion");
}

sub apply_missing_eval {
	my ($self, $migration, $links) = @_;
	
	$self->_for_each_undefinded_rule(
		sub {
			my ($table_6, $column_6) = @_;

			my $eval = $migration->get_column_eval($table_6, $column_6, $links);
			if (defined $eval) {
				return Migration::Rule::Eval->new($eval->{'eval'}, undef, undef);
			}
			return undef;
		}
	);

	## hard-coded evals

	## eval for active office id
	$self->{'rules'}{'office_user_sensitive:2'}{'active'} = Migration::Rule::Eval->new('office-active', undef, undef);
	delete $self->{'rules'}{'office_user_sensitive'}{'active'};
	$self->{'tables'}{'office_user_sensitive:2'} = { %{ $self->{'tables'}{'office_user_sensitive'} } };
	$self->{'tables'}{'office_user_sensitive:2'}{'action'} = 'update-office-active';

	$self->{'rules'}{'referrer_user_sensitive'}{'si_doctor_id'} = Migration::Rule::Eval->new('si-doctor-id', 'si_pms_referrer_link', 'pms_referrer_id');

	## eval for voice end message id
	$self->{'rules'}{'client_setting:2'}{'IVal'} = Migration::Rule::Eval->new('voice-end-message-id', undef, undef);
	$self->{'tables'}{'client_setting:2'} = { %{ $self->{'tables'}{'client_setting'} } };
	$self->{'tables'}{'client_setting:2'}{'action'} = 'update-voice-end-message-id';

	## eval for si auto notify
	$self->{'rules'}{'client_setting:3'}{'IVal'} = Migration::Rule::Eval->new('si-auto-notify', undef, undef);
	$self->{'tables'}{'client_setting:3'} = { %{ $self->{'tables'}{'client_setting'} } };
	$self->{'tables'}{'client_setting:3'}{'action'} = 'update-si-auto-notify';

	## eval for first si theme message id
	$self->{'rules'}{'si_theme:2'}{'FirstMesId'} = Migration::Rule::Eval->new('first-theme-message-id', undef, undef);
	$self->{'tables'}{'si_theme:2'} = { %{ $self->{'tables'}{'si_theme'} } };
	$self->{'tables'}{'si_theme:2'}{'action'} = 'update-first-theme-message-id';

}

sub apply_links {
	my ($self, $links, $migration) = @_;
	
	$self->_for_each_undefinded_rule(
		sub {
			my ($table_6, $column_6) = @_;

			my $link = $links->get_link_from($table_6, $column_6);
			if (defined $link && ! defined $migration->get_hardcoded_lookup($table_6, $column_6) && ! defined $migration->get_column_eval($table_6, $column_6, $links)) {
				my $link_info = $link->{'link_info'} // {};
				return Migration::Rule::ForeignKey->new(
					$link->{'to_table'}, 
					$link->{'to_column'}, 
					$link_info->{'table'}, 
					$link_info->{'column'}
				)->set_source($link->{'comment'});
			}
			return undef;
		}
	);
}

sub apply_moved_tables {
	my ($self, $migration, $schema_5_list, $schema_6, $links) = @_;

	my $column_rules = $self->{'rules'};

	my $stop = 0;
	for my $column (@$schema_5_list) {
		my $new_names = $migration->get_new_names($column->{'TABLE_NAME'});
		for my $new_name (@$new_names) {
			if (exists $column_rules->{$new_name}) {
				my $new_column = $migration->column_name_after_rename($column->{'TABLE_NAME'}, $column->{'COLUMN_NAME'});
				if (exists $column_rules->{$new_name}{$new_column} && 
					! defined $column_rules->{$new_name}{$new_column}
				) {
					if (defined $migration->get_column_eval($new_name, $new_column, $links)) {
						my $column_eval = $migration->get_column_eval($new_name, $new_column, $links);
						$column_rules->{$new_name}{$new_column} = Migration::Rule::Eval->new(
							$column_eval->{'eval'}, 
							($column_eval->{'unknown_column'} ? (
								undef,
								undef,
							) : (							
								$column->{'TABLE_NAME'},
								$column->{'COLUMN_NAME'},
							) )
						);
					} elsif (defined $migration->get_hardcoded_lookup($new_name, $new_column)) {
						$column_rules->{$new_name}{$new_column} = Migration::Rule::HardCodedLookup->new(
							$migration->get_hardcoded_lookup($new_name, $new_column), 
							$column->{'TABLE_NAME'},
							$column->{'COLUMN_NAME'}
						);
					} elsif ($self->can_copy_type(
							\$stop, 
							$migration, $column, 
							$schema_6->{ $migration->get_table_name($new_name) }{$new_column}
						)
					) {
						if ($new_name eq $column->{'TABLE_NAME'}) {
							$column_rules->{$new_name}{$new_column} = Migration::Rule::CopyValue->new(
								$column->{'TABLE_NAME'}, 
								$column->{'COLUMN_NAME'}
							);
						} else {
							$column_rules->{$new_name}{$new_column} = Migration::Rule::CopyValue->new(
								$column->{'TABLE_NAME'}, 
								$column->{'COLUMN_NAME'}
							);
						}
					}
				}
			}
		}
	}
	$self->{'logger'}->stop($stop, "incompatible column types");
}

sub can_copy_type {
	my ($self, $stop_ref, $migration, $from_column, $to_column) = @_;

	if (lc $from_column->{'IS_NULLABLE'} eq lc $to_column->{'IS_NULLABLE'}) {
		if ($migration->is_column_type_ignored($to_column->{'TABLE_NAME'}, $to_column->{'COLUMN_NAME'})) {
			return 1;
		} else {
			if ($self->_is_column_type_equal($from_column->{'COLUMN_TYPE'}, $to_column->{'COLUMN_TYPE'})) {
				return 1;
			} else {
				$self->{'logger'}->printf(
					"types didn't match [%s.%s: %s] => [%s.%s: %s]",
					$from_column->{'TABLE_NAME'},
					$from_column->{'COLUMN_NAME'},
					$from_column->{'COLUMN_TYPE'},
					$to_column->{'TABLE_NAME'},
					$to_column->{'COLUMN_NAME'},
					$to_column->{'COLUMN_TYPE'},
				);
				$$stop_ref ++;
			}
		}
	} else {
		if (lc $to_column->{'IS_NULLABLE'} eq 'no' && ! $migration->is_nullable_ignored($to_column->{'TABLE_NAME'}, $to_column->{'COLUMN_NAME'})) {
			$self->{'logger'}->printf(
				"nullable didn't match [%s.%s: %s] => [%s.%s: %s]",
				$from_column->{'TABLE_NAME'},
				$from_column->{'COLUMN_NAME'},
				(lc $from_column->{'IS_NULLABLE'} eq 'no' ? "NOT NULL" : "NULL"),
				$to_column->{'TABLE_NAME'},
				$to_column->{'COLUMN_NAME'},
				(lc $to_column->{'IS_NULLABLE'} eq 'no' ? "NOT NULL" : "NULL"),
			);
			$$stop_ref ++;
		} else {
			return 1;
		}
	}
	return 0;
}

sub _is_column_type_equal {
	my ($self, $from_type, $to_type) = @_;
	
	my $from = $self->_prepare_type($from_type);
	my $to = $self->_prepare_type($to_type);

	if ($from eq $to) {
		return 1;
	} elsif ($from eq "text" && $to eq "mediumtext") {
		return 1;
	} elsif ($from eq "text" && $to eq "longtext") {
		return 1;
	} elsif ($from eq "tinyint" && $to eq "int") {
		return 1;
	} elsif ($from =~ m{^enum} && $to =~ m{^enum}) {
		my ($from_set) = ($from =~ m{^enum\((.*)\)$});
		my ($to_set) = ($to =~ m{^enum\((.*)\)$});
		my %to_enum = map {$_ => 1} split(',', $to_set);
		for my $from_val (split(',', $from_set)) {
			unless (exists $to_enum{$from_val}) {
				return 0;
			}
		}
		return 1;
	} else {
		return 0;
	}
}

sub _prepare_type {
	my ($self, $type) = @_;

	$type =~ s{(?<=int)\(\d+\)}{}g;
	return lc $type;
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
		'comments' => {},
		'link_info' => {},
	}, $class;
	return $self;
}

sub _get_table_name {
	my ($table) = @_;
	
	$table =~ s{:.*$}{};
	return $table;
}

sub add_link {
	my ($self, $from_table, $to_table, $columns, $comment, $link_info) = @_;

	if ($self->is_link_exists($from_table, $to_table, $columns)) {
		die "link [$from_table] -> [$to_table] on [".$self->_columns_to_string($columns)."] is already defined (".
			$self->{'comments'}{$from_table}{$to_table}{ _columns_key($columns) }.")";
	}
	$self->{'links'}{$from_table}{$to_table}{ _columns_key($columns) } = $columns;
	$self->{'comments'}{$from_table}{$to_table}{ _columns_key($columns) } = $comment;
	unless (defined $link_info) {
		if (keys(%$columns) == 1) {
			$link_info = {
				'table' => $from_table,
				'column' => (keys(%$columns))[0],
			};
		}
	}
	$self->{'link_info'}{$from_table}{$to_table}{ _columns_key($columns) } = $link_info;
}

sub add_links {
	my ($self, $links, $comment) = @_;
	
	while (my ($from, $to) = each %$links) { 
		my ($from_table, $from_column) = split('\.', $from, 2);
		my ($to_table, $to_column) = split('\.', $to, 2);
		$self->add_link(
			$from_table, 
			$to_table, 
			{
				$from_column => $to_column,
			},
			$comment
		);
	}
}

sub for_each_link_from {
	my ($self, $from_table, $callback) = @_;
	
	if (exists $self->{'links'}{$from_table}) {
		for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
			for my $columns (values %{ $self->{'links'}{$from_table}{$to_table} }) {
				$callback->($to_table, { %$columns });
			}
		}
	}
}

sub _columns_key {
	my ($columns) = @_;

	return join("|", sort keys %$columns);
}

sub is_link_exists {
	my ($self, $from_table, $to_table, $columns) = @_;

	$from_table = _get_table_name($from_table);
	$to_table   = _get_table_name($to_table);
	return exists $self->{'links'}{$from_table}{$to_table}{ _columns_key($columns) };
}

sub is_link_exists_from_column_to_table {
	my ($self, $from_table, $from_column, $to_table) = @_;
	
	$from_table = _get_table_name($from_table);
	$to_table   = _get_table_name($to_table);
	return exists $self->{'links'}{$from_table}{$to_table}{$from_column};
}

sub is_link_exists_from_column {
	my ($self, $from_table, $from_column) = @_;
	
	$from_table = _get_table_name($from_table);
	if (exists $self->{'links'}{$from_table}) {
		for my $link_info (values %{ $self->{'links'}{$from_table} }) {
			if (exists $link_info->{$from_column}) {
				return 1;
			}
		}
	}
	return 0;
}

sub is_link_exists_between_tables {
	my ($self, $from_table, $to_table) = @_;
	
	$from_table = _get_table_name($from_table);
	$to_table   = _get_table_name($to_table);
	return exists $self->{'links'}{$from_table}{$to_table};
}

sub get_link_column_between_tables {
	my ($self, $from_table, $to_table) = @_;
	
	$from_table = _get_table_name($from_table);
	$to_table   = _get_table_name($to_table);
	unless ($self->is_link_exists_between_tables($from_table, $to_table)) {
		die "link from [$from_table] to [$to_table] doesn't exist";
	}
	my $link_info = $self->{'links'}{$from_table}{$to_table};
	return (keys %{ (values %$link_info)[0] })[0];
}

sub get_link_from {
	my ($self, $from_table, $from_column) = @_;

	$from_table = _get_table_name($from_table);
	if (exists $self->{'links'}{$from_table}) {
		for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
			my $links = $self->{'links'}{$from_table}{$to_table};
			for my $link_key (keys %$links) {
				my $link_info = $links->{$link_key};
				if (exists $link_info->{$from_column}) {
					return {
						'to_table' => $to_table,
						'to_column' => $link_info->{$from_column},
						'comment' => $self->{'comments'}{$from_table}{$to_table}{$link_key},
						'link_info' => $self->{'link_info'}{$from_table}{$to_table}{$link_key},
					};
				}
			}
		}
	}
	return undef;
}

sub remove_link_not_from_tables {
	my ($self, $allowed_tables) = @_;

	for my $from_table (keys %{ $self->{'links'} }) {
		unless ($allowed_tables->{$from_table}) {
			delete $self->{'links'}{$from_table};
		}
	}
}

sub verify_broken_links {
	my ($self, $logger, $allowed_tables, $migration) = @_;
	
	my @stop;
	for my $from_table (keys %{ $self->{'links'} }) {
		for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
			unless (exists $allowed_tables->{$to_table}) {
				for my $from_column_str (keys %{ $self->{'links'}{$from_table}{$to_table} }) {
					if ($migration->is_lookup($from_table, $from_column_str)) {
						## ignore lookups
					} else {
						push(@stop, sprintf("table [%s] was removed, but link is in [%s.%s]", $to_table, $from_table, $from_column_str));
					}
				}
			}
		}
	}
	for my $msg (sort @stop) {
		$logger->printf($msg);
	}
	$logger->stop(scalar @stop, "broken links");
}

sub rename_tables {
	my ($self, $migration, $schema_6) = @_;

	my %links;
	for my $from_table (keys %{ $self->{'links'} }) {
		my $new_from_tables = $migration->get_new_names($from_table);
		for my $new_from_table (@$new_from_tables) {
			if (exists $schema_6->{$new_from_table}) {
				for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
					my $new_link_info = $self->_clear_link_info(
						$self->{'links'}{$from_table}{$to_table},
						$schema_6->{$new_from_table},
					);
					if (keys %$new_link_info) {
						my $new_to_table = $migration->table_to_name_after_renamed($to_table);
						$links{$new_from_table}{$new_to_table} = $new_link_info;
						for my $link_key (keys %$new_link_info) {
							unless (exists $self->{'comments'}{$new_from_table}{$new_to_table}{$link_key}) {
								$self->{'comments'}{$new_from_table}{$new_to_table}{$link_key} = "from ".$from_table.
									" by rename (old ".$self->{'comments'}{$from_table}{$to_table}{$link_key}.")";
							}
							unless (exists $self->{'link_info'}{$new_from_table}{$new_to_table}{$link_key}) {
								my %link_info = %{ $self->{'link_info'}{$from_table}{$to_table}{$link_key} };
								##$link_info{'table'} = $new_from_table;
								$self->{'link_info'}{$new_from_table}{$new_to_table}{$link_key} = \%link_info;
							}
						}
					}
				}
			}
		}
	}
	$self->{'links'} = \%links;
}

sub delete_link_between_tables {
	my ($self, $from_table, $to_table) = @_;

	$from_table = _get_table_name($from_table);
	$to_table   = _get_table_name($to_table);
	unless (exists $self->{'links'}{$from_table}{$to_table}) {
		die "can't delete link [$from_table] -> [$to_table]: link doesn't exist";
	}
	delete $self->{'links'}{$from_table}{$to_table};
	delete $self->{'comments'}{$from_table}{$to_table};
	delete $self->{'link_info'}{$from_table}{$to_table};
}

sub _clear_link_info {
	my ($self, $link_info, $allowed_columns) = @_;
	
	my %new_link_info;
	for my $columns (values %$link_info) {
		my %new_columns = map { $_ => $columns->{$_} } grep {exists $allowed_columns->{$_}} keys %$columns;
		if (keys %new_columns) {
			$new_link_info{ _columns_key(\%new_columns) } = \%new_columns;
		}
	}
	return \%new_link_info;
}

sub _columns_to_string {
	my ($self, $columns) = @_;
	
	return join(" AND ", map { $_."=".$columns->{$_} } sort keys %$columns);
}


package Migration;

sub new {
	my ($class, $schema_6, $required_tables) = @_;

	tie my %renamed, 'Tie::IxHash', (
		'address_office_fake' => 'office_address_local',
		'address_visitor_fake' => 'address_local',
		'appointment_extension' => 'appointment_versioned',
		'email_local_fake' => 'email_local',
		'email_reminder_settings' => 'email_reminder_settings',
		'email_reminder_settings_standard_fake' => 'email_reminder_settings',
		'email_sent_mail_log_archive' => 'email_sent_mail_log',
		'patient_pages_message' => 'patient_page_messages',
		'phone_local_fake' => 'phone_local',
		'ppn_article_letter' => 'ppn_article_letter',
		'ppn_article_letter_common_fake' => 'ppn_article_letter',
		'referrer_email_log_fake' => 'referrer_email_log',
		'referrer_local_fake' => 'si_doctor',
		'si_doctor_email_log_fake' => 'si_doctor_email_log',
		'voice_office_name_pronunciation' => 'office_user_sensitive',
	);

	my $self = bless {
		'removed' => {
			map {$_ => 1} (
				'si_image_old', 'phone_sms_active_from_upload', 'phone_temp', 
				## pms data tables
				'account', 'appointment_procedure', 'insurance_contract', 'ledger', 
				'patient_referrer', 'patient_staff', 'treatment_plan', 
				## removed by Dan 
				'upload_last', 
			) 
		},
		'renamed' => \%renamed,
		'renamed_columns' => {
			'voice_office_name_pronunciation' => {
				'guid' => 'voice_pronunciation_guid',
				'office_name' => 'voice_pronunciation_name',
			},
			'patient_pages_message' => {
				'do_not_show_after' => 'show_until',
				'patient_page' => 'page_type',
			},
		},
		'hardcoded_lookup' => {
			'survey_answer' => {
				'question_id' => 'survey-question-id',
				'question_option_id' => 'survey-option-id',
			},
			'holiday_settings' => {
				'hdc_id' => 'holiday-card-id',
				'hd_id' => 'holiday-id',
			},
			'holiday_delivery_log' => {
				'hdc_id' => 'holiday-card-id',
				'hd_id' => 'holiday-id',
			},
			'holiday_settings_recipients_link' => {
				'hr_id' => 'holiday-recipient-id',
			},
			'holiday_settings_recipients_link_log' => {
				'hr_id' => 'holiday-recipient-id',
			},
			'client_feature' => {
				'feature_id' => 'feature-id',
			},
			'client' => {
				'client_edition_id' => 'client-edition-id',
				'pms_software_id' => 'pms-software-id',
			},
			'ppn_letter_logo' => {
				'logo_id' => 'ppn-logo-id',
			},
			'ppn_article_queue' => {
				'art_id' => 'newsletter-common-article-id',
			},
			'ppn_article_letter:2' => {
				'art_id' => 'newsletter-common-article-id',
			},
			'email_reminder_settings' => {
				'design_id' => 'email-design-id',
			},
			'email_sending_queue' => {
				'design_id' => 'email-design-id',
			},
			'hits_count' => {
				'hcount_sect_id' => 'hit-section-id',
			},
			'hits_log' => {
				'hlog_sect_id' => 'hit-section-id',
			},
			'upload_postprocessing_task' => {
				'postprocessing_action_id' => 'post-upload-action-id',
			},
			'orthomation' => {
				'node_id' => 'orthomation-node-id',
			},
			'visitor_opinion' => {
				'category_id' => 'visitor-opinion-category-id',
			},
			'patient_page_messages' => {
				'show_forever' => 'boolean-to-integer',
			},
			'email_local' => {
				'source' => 'email-source',
			},
			'phone_local' => {
				'source' => 'phone-source',
			},
			'voice_message_history' => {
				'sent_type' => 'voice-sent-type',
			},
			'si_standard_message' => {
				'NotDeleted' => 'si-message-not-deleted',
			},
		},
		'constant_value' => {
			'appointment_user_sensitive' => {
				'reactivation_sent' => 'false',
			},
			'hhf_applications' => {
				'deleted' => '0',
			},
			'hhf_templates' => {
				'name' => 'base',
				'modify_date' => '2011-11-01 00:00:00',
			},
			'recall_user_sensitive' => {
				'reactivation_sent' => 'false',
			},
			'referrer_user_sensitive' => {
				'deleted' => '0',
			},
			'si_theme' => {
				'FirstMesId' => '0', ## need to be fixed by second rule
			},
		},
		'ignore_nullable' => {
			'email_sent_mail_log' => {
				'subject' => 1,
			},
			'hhf_templates' => {
				'body' => 1,
			},
			'patient_page_messages' => {
				'message' => 1,
				'show_until' => 1,
			},
			'office_user_sensitive' => {
				'voice_pronunciation_name' => 1,
			},
			'phone_user_sensitive' => {
				'sms_active' => 1,
				'voice_active' => 1,
			},
			'responsible_patient_user_sensitive' => {
				'hide_patient' => 1,
			},
			'si_doctor' => {
				'FName' => 1,
				'LName' => 1,
				'email' => 1,
			},
		},
		'ignore_type_change' => {
			'appointment_confirmation_history' => {
				'client_id' => 1,
			},
			# 'client' => {
			# 	'cl_start_date' => 1,
			# },
			'email_sent_mail_log' => {
				'sml_body' => 1,
			},
			'email_sent_mail_log_archive' => {
				'sml_body' => 1,
			},
			'procedure_user_sensitive' => {
				'client_id' => 1,
			},
			'si_theme' => {
				'client_id' => 1,
			},
			'voice_left_messages' => {
				'voice_queue_id' => 1,
			},
			'voice_qa_record' => {
				'voice_queue_id' => 1,
			},
			'voice_transactions_log' => {
				'voice_queue_id' => 1,
			},
			'voice_system_transaction_log' => {
				'voice_queue_id' => 1,
			},
			'voice_message_history' => {
				'voice_queue_id' => 1,
			},
			'office_address_local' => {
				'client_id' => 1,
			},
			'si_standard_message' => {
				'NotDeleted' => 1,
			},
			'si_doctor' => {
				'AutoNotify' => 1,
				'Deleted' => 1,
				'Password' => 1,
				'PrivacyAccepted' => 1,
				'WelcomeSent' => 1,
			},
		},
		'ignore_columns' => {
			'client' => {
				'cl_start_date' => 1,
				'cl_status' => 1,
			},
			'referrer_user_sensitive' => {
				'password' => 1,
			},
		},
		'update_on' => {
			'client' => ['cl_username'],
			'client_setting' => ['client_id', 'PKey'],
			'email_reminder_settings' => ['client_id', 'type'],
			'srm_resource' => ['id'],
			'upload_settings' => ['client_id', 'name'],
		},
		'path_to_client' => {
			'ppn_article_letter' => [
				{
					'table' => 'ppn_article_letter',
					'column' => 'let_id',
				},
				{
					'table' => 'ppn_letter',
					'column' => 'client_id',
				},
			],
			'ppn_article_letter:2' => [
				{
					'table' => 'ppn_article_letter',
					'column' => 'let_id',
				},
				{
					'table' => 'ppn_letter',
					'column' => 'client_id',
				},
			],
			'srm_resource' => [],
			'sms_message_history' => [
				{
					'table' => 'sms_message_history',
					'column' => 'client_id',
				},
				{
					'table' => 'sms_client_settings',
					'column' => 'client_id',
				}
			],
			'sms_message_response' => [
				{
					'table' => 'sms_message_response',
					'column' => 'client_id',
				},
				{
					'table' => 'sms_client_settings',
					'column' => 'client_id',
				}
			],
		},
		'need_convert_datetime' => {
			'email_contact_log' => {
				'clog_sdate' => 'server',
			},
			'email_sent_mail_log' => {
				'sml_date' => 'server',
			},
			'sms_message_history' => {
				'registered' => 'server',
				# 'time2send' => 'utc',
				# 'processed' => 'utc',
				# 'SentTime' => 'utc',
				'appointment_datetime' => 'server',
			},
			'sms_queue' => {
				'registered' => 'server',
				# 'time2send' => 'utc',
				'appointment_datetime' => 'server',
			},
			'voice_message_history' => {
				'time2send' => 'server',
				'sent_date' => 'server',
				'event_datetime' => 'server',
			},
			'voice_queue' => {
				'time2send' => 'server',
				'sent_date' => 'server',
				'create_datetime' => 'server',
			},
		},
		'date_column' => {
			'email_contact_log' => 'clog_sdate',
			'email_post_app_survey_log' => 'date',
			'email_referral' => 'email_referral_mail.sending_date',
			'email_referral_mail' => 'sending_date',
			'email_sent_mail_log' => 'sml_date',
			'hhf_applications' => 'filldate',
			'opse_payment_log' => 'Time',
			'sms_message_history' => 'time2send',
			'sms_message_response' => 'ResponseReceiveDate',
			'sms_queue' => 'time2send',
			'token' => 'timestamp',
			'voice_left_messages' => 'call_time',
			'voice_message_history' => 'time2send',
			'voice_queue' => 'time2send',
			'voice_recipient_list' => 'voice_message_history.time2send',
			'voice_system_transaction_log' => 'eventtime_utc',
			'voice_transactions_log' => 'starttime_utc',
		},
		'eval' => {
			# 'office_user_sensitive' => {
			# 	'active' => 'office-active',
			# },
			'si_image' => {
				'imageUrl' => {
					'eval' => 'si-image-url',
					'unknown_column' => 1,
				},
			},
			'email_sent_mail_log' => {
				'subject' => {
					'eval' => 'email-archive-subject',
					'unknown_column' => 1,
				},
				'sml_body' => {
					'eval' => 'email-archive-body',
				}
			},
			'email_reminder_settings' => {
				'type' => {
					'eval' => 'email-reminder-setting-type',
				},
			},
			'client' => {
				'id' => {
					'eval' => 'client-id',
				},
			},
			'referrer_user_sensitive' => {
				'si_doctor_id' => {
					'eval' => 'si-doctor-id',
				},
			},
			'opse_payment_log' => {
				'patient_id' => {
					'eval' => 'patient-id-for-opse',
				},
			},
		},
	}, $class;
	$self->_detect_renames_to_same_table();
	$self->_generate_versioned_rules($schema_6, $required_tables);
	$self->_generate_actions($required_tables);
	$self->_generate_autoincrement($schema_6);
	return $self;
}

sub _detect_renames_to_same_table {
	my ($self) = @_;

	my (%secondary_rules, %unique);
	while (my ($from, $to) = each %{ $self->{'renamed'} }) {
		if (exists $unique{$to}) {
			$unique{$to}++;
			my $table_to = $to.":".$unique{$to};
			$self->{'renamed'}{$from} = $table_to;
			push(@{ $secondary_rules{$to} }, $table_to);
		} else {
			$unique{$to} = 1;
		}
	}
	$self->{'secondary_rules'} = \%secondary_rules;
}

sub get_secondary_rule_names {
	my ($self, $table_5) = @_;
	
	return (exists $self->{'secondary_rules'}{$table_5} ? $self->{'secondary_rules'}{$table_5} : []);
}

sub get_table_name {
	my ($self, $table) = @_;

	unless (defined $table) {
		die "table name can't be undef";
	}
	
	$table =~ s{:.*$}{};
	return $table;
}

sub ignore_table_6 {
	my ($self, $table_6) = @_;

	return $table_6 eq 'si_pms_referrer_link';
}

sub _generate_actions {
	my ($self, $required_tables) = @_;
	
	my %know_actions = map {$_ => 1} ("delete-insert", "insert", "update", "update-insert", "remap-only");
	my %actions;
	for my $table (@$required_tables) {
		if ($table->{'action'} eq 'user-sensitive') {
			$actions{$table->{'table'}."_user_sensitive"} = "update";
			$actions{$table->{'table'}} = "remap-only";
		} elsif (exists $know_actions{$table->{'action'}}) {
			$actions{ $self->table_to_name_after_renamed($table->{'table'}) } = $table->{'action'};
			for my $secondary_rule (@{ $self->get_secondary_rule_names($table->{'table'}) }) {
				$actions{$secondary_rule} = $table->{'action'};
			}
		} elsif (!$table->{'action'}) {
			## ignore empty actions
		} else {
			die "unknown action [".$table->{'action'}."]";
		}
	}
	$self->{'actions'} = \%actions;
}

sub _generate_versioned_rules {
	my ($self, $schema_6, $required_tables) = @_;

	my %versioned;
	for my $table (@$required_tables) {
		if ($table->{'transform'} eq "user-sensitive") {
			$versioned{ $table->{'table'} } = [ $table->{'table'}, $table->{'table'}."_user_sensitive" ];
		} elsif ($table->{'transform'} eq "remap-only") {
			$versioned{ $table->{'table'} } = [ $table->{'table'} ];
		}
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
	## we are not inserting into client
	delete $autoincrement{'client'}{'id'};
	$self->{'autoincrement'} = \%autoincrement;
}

sub _get_versioned_name_base {
	my ($self, $name) = @_;
	
	if ($name =~ m{^(.*)_versioned$}) {
		return $1;
	} else {
		return undef;
	}
}

sub is_column_autoincrement {
	my ($self, $table_6, $column_6) = @_;

	$table_6 = $self->get_table_name($table_6);
	return $self->{'autoincrement'}{$table_6}{$column_6};
}

sub is_column_ignored {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return $self->{'ignore_columns'}{$table_6}{$column_6};
}

sub get_update_on_columns {
	my ($self, $table_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return (exists $self->{'update_on'}{$table_6} ? [ @{ $self->{'update_on'}{$table_6} } ] : undef);
}

sub get_path_to_client {
	my ($self, $table_6) = @_;

	return $self->{'path_to_client'}{$table_6};
}

sub table_removed {
	my ($self, $table_5) = @_;

	return exists $self->{'removed'}{$table_5};
}

sub table_name_after_renamed {
	my ($self, $table_5) = @_;

	return $self->get_table_name($self->table_to_name_after_renamed($table_5));
}

sub table_to_name_after_renamed {
	my ($self, $table_5) = @_;

	if (exists $self->{'renamed'}{$table_5}) {
		return $self->{'renamed'}{$table_5};
	} else {
		return $table_5;
	}
}

sub column_name_after_rename {
	my ($self, $table_5, $column_5) = @_;	

	if (exists $self->{'renamed_columns'}{$table_5}{$column_5}) {
		return $self->{'renamed_columns'}{$table_5}{$column_5};
	} else {
		return $column_5;
	}
}

sub get_need_convert_datetime {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return $self->{'need_convert_datetime'}{$table_6}{$column_6};
}

sub get_column_eval {
	my ($self, $table_6, $column_6, $links) = @_;
	
	my $link = $links->get_link_from($table_6, $column_6);
	if (defined $link && $link->{'to_table'} eq 'client' && $link->{'to_column'} eq 'id') {
		return $self->{'eval'}{$link->{'to_table'}}{$link->{'to_column'}}
	} else {
		return $self->{'eval'}{$table_6}{$column_6};
	}
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

sub is_table_versioned {
	my ($self, $table_5) = @_;

	return exists $self->{'versioned'}{$table_5};
}

sub is_column_from_pms {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
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

sub get_tables_with_remap_only_action {
	my ($self) = @_;

	return [ grep {$self->{'actions'}{$_} eq "remap-only"} keys %{ $self->{'actions'} } ];
}

sub is_lookup {
	my ($self, $table_6, $column_6) = @_;

	$table_6 = $self->get_table_name($table_6);
	return exists $self->{'hardcoded_lookup'}{$table_6}{$column_6} || $self->{'conditional_lookup'}{$table_6}{$column_6};
}

sub get_hardcoded_lookup {
	my ($self, $table_6, $column_6) = @_;
	
	unless (exists $self->{'hardcoded_lookup'}{$table_6}{$column_6}) {
		$table_6 = $self->get_table_name($table_6);
	}
	return $self->{'hardcoded_lookup'}{$table_6}{$column_6};
}

sub is_constant_value_exists {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return exists $self->{'constant_value'}{$table_6}{$column_6};
}

sub get_constant_value {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return $self->{'constant_value'}{$table_6}{$column_6};
}

sub is_nullable_ignored {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return $self->{'ignore_nullable'}{$table_6}{$column_6};
}

sub is_column_type_ignored {
	my ($self, $table_6, $column_6) = @_;
	
	$table_6 = $self->get_table_name($table_6);
	return $self->{'ignore_type_change'}{$table_6}{$column_6};
}

sub get_date_column {
	my ($self, $table_6) = @_;
	
	my $info = $self->{'date_column'}{$table_6};
	my ($table, $column) = ($table_6, $info);
	if ($info =~ m{\.}) {
		($table, $column) = split(m{\.}, $info, 2);
	}
	return {
		'legacy_table' => $table,
		'legacy_column' => $column,
	};
}

sub load_hard_coded_links {
	my ($self, $links) = @_;

	## client_id
	for my $from_table (
		"appointment_reminder_schedule", "email_contact_log", "email_sent_mail_log", "upload_settings", 
		"address_local", "email_local", "office_address_local", "patient_page_messages", "phone_local", "referrer_local",
		"email_referral_mail", "ppn_article_letter", "email_referral", "voice_recipient_list", "referrer_email_log",
		"referrer_user_sensitive", "si_doctor_email_log"
	) {
		$links->add_link(
			$from_table, 
			"client", 
			{
				'client_id' => "id",
			},
			"hard-coded",
		);
	}

	## visitor_id
	for my $link (
		"email_local_fake.visitor_id", "phone_local_fake.visitor_id", 
		"opse_payment_log.patient_id", "token.user_id"
	) {
		my ($from_table, $from_column) = split('\.', $link);
		$links->add_link(
			$from_table, 
			"visitor", 
			{
				$from_column => "id",
			},
			"hard-coded",
		);
	}

	$links->add_link(
		"address_local", 
		"visitor", 
		{
			"visitor_id" => "id",
		},
		"hard-coded",
		{
			'table' => 'address_visitor_fake',
			'column' => 'id',
		}
	);

	$links->add_link(
		"address_office_fake", 
		"office", 
		{
			"office_id" => "id",
		},
		"hard-coded",
		{
			'table' => 'address_office_fake',
			'column' => 'id',
		}
	);

	$links->add_link(
		"sms_message_history", 
		"sms_client_settings", 
		{
			"client_id" => "Id",
		},
		"hard-coded",
		{
			'table' => 'sms_message_history',
			'column' => 'client_id',
		}
	);

	$links->add_link(
		"sms_message_response", 
		"sms_client_settings", 
		{
			"client_id" => "Id",
		},
		"hard-coded",
		{
			'table' => 'sms_message_response',
			'column' => 'client_id',
		}
	);

	$links->add_link(
		"si_doctor_email_log_fake", 
		"si_doctor", 
		{
			"si_doctor_id" => "DocId",
		},
		"hard-coded",
		{
			'table' => 'si_doctor_email_log_fake',
			'column' => 'si_doctor_id',
		}
	);

	$links->add_link(
		"referrer_email_log_fake", 
		"referrer", 
		{
			"referrer_id" => "id",
		},
		"hard-coded",
		{
			'table' => 'referrer_email_log_fake',
			'column' => 'referrer_id',
		}
	);

	## other
	$links->add_links(
		{
			'client_access.user_name' => 'client.cl_username',
			'email_referral.referral_mail_id' => 'email_referral_mail.id',
			'email_referral.referrer_id' => 'visitor.id', ## type column is in fact 'visitor' for all records
			'invisalign_case_process_patient.invisalign_client_id' => 'invisalign_client.id',
			#'address_office_fake.office_id' => 'office.id',
			'orthomation.node_id' => 'orthomation_nodes.node_id',
			#'ppn_article_letter.art_id' => 'ppn_article.id',
			# 'si_pms_referrer_link.pms_referrer_id' => 'referrer.id',
			# 'si_pms_referrer_link.referrer_id' => 'referrer.id',
			'referrer_user_sensitive.si_doctor_id' => 'si_doctor.DocId',
			#'referrer_user_sensitive.referrer_id' => 'referrer.id',
			'srm_resource.container' => 'client.cl_username',
			'visitor_opinion.category_id' => 'review_category.id',
			'voice_left_messages.rec_id' => 'voice_recipient_list.RLId',
			'voice_message_history.rec_id' => 'voice_recipient_list.RLId',
		},
		"hard-coded",
	);
	## user sensitive
	my %user_sensitive_links = (
		'email_user_sensitive.email_id' => 'email',
		'phone_user_sensitive.phone_id' => 'phone',
		'procedure_user_sensitive.procedure_id' => 'procedure',
		'recall_user_sensitive.recall_id' => 'recall',
		'responsible_patient_user_sensitive.responsible_patient_id' => 'responsible_patient',
		'visitor_user_sensitive.visitor_id' => 'visitor',
		'referrer_user_sensitive.referrer_id' => 'referrer',
	);
	for my $link (keys %user_sensitive_links) {
		my ($from_table, $from_column) = split('\.', $link);
		$links->add_link(
			$from_table, 
			$user_sensitive_links{$link}, 
			{
				$from_column => "id",
			},
			"hard-coded",
			{
				'table' => $user_sensitive_links{$link},
				'column' => 'id',
			}
		);
	}
}

sub restore_remap_only_links {
	my ($self, $links) = @_;
	
	$links->add_links(
		{
			'address.client_id' => 'client.id',
			'appointment.client_id' => 'client.id',
			'email.client_id' => 'client.id',
			'office.client_id' => 'client.id',
			'phone.client_id' => 'client.id',
			'procedure.client_id' => 'client.id',
			'recall.client_id' => 'client.id',
			'responsible_patient.client_id' => 'client.id',
			'staff.client_id' => 'client.id',
			'visitor.client_id' => 'client.id',
		},
		"remap-only",
	);
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

sub set_source {
	my ($self, $source) = @_;
	
	$self->{'source'} = $source;
	return $self;
}

sub get_source {
	my ($self) = @_;
	
	return $self->{'source'};
}

package Migration::Rule::ForeignKey;

use base qw(Migration::Rule);

sub new {
	my ($class, $table, $column, $from_table, $from_column) = @_;
	
	my $self = bless {
		'table' => $table,
		'column' => $column,
		'from_table' => $from_table,
		'from_column' => $from_column,
	}, $class;
	return $self;
}

sub as_string {
	my ($self) = @_;
	
	return "link to [".$self->{'table'}.".".$self->{'column'}."]".
		(defined $self->{'from_table'} ? " from [".$self->{'from_table'}.".".$self->{'from_column'}."]" : "").
		($self->{'source'} ? " (".$self->{'source'}.")" : "");
}

sub as_json {
	my ($self) = @_;

	tie my %r, "Tie::IxHash", (
		'action' => "foreign-key",
		'lookup_table' => $self->{'table'},
		'lookup_column' => $self->{'column'},
	);
	if (defined $self->{'from_table'}) {
		$r{'from_table'} = $self->{'from_table'};
		$r{'from_column'} = $self->{'from_column'};
	}
	return \%r;
}

package Migration::Rule::CopyValue;

use base qw(Migration::Rule);

sub new {
	my ($class, $table, $column) = @_;
	
	my $self = bless {
		'table' => $table,
		'column' => $column,
		'action' => 'copy',
	}, $class;
	return $self;
}

sub as_string {
	my ($self) = @_;
	
	return $self->{'action'}." value from [".$self->{'table'}.".".$self->{'column'}."]";
}

sub as_json {
	my ($self) = @_;

	tie my %r, "Tie::IxHash", (
		'action' => $self->{'action'},
		'from_table' => $self->{'table'},
		'from_column' => $self->{'column'},
	);
	return \%r;
}

sub set_copy_and_save {
    my ($self) = @_;
	
	$self->{'action'} = 'copy-and-save';
}

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
		'action' => "autoincrement",
	};
}

package Migration::Rule::HardCodedLookup;

use base qw(Migration::Rule);

sub new {
	my ($class, $map, $table, $column) = @_;
	
	my $self = bless {
		'map' => $map,
		'table' => $table,
		'column' => $column,
	}, $class;
	return $self;
}

sub as_string {
	my ($self) = @_;
	
	return "hard-coded lookup: map [".$self->{'map'}."] value from [".$self->{'table'}.".".$self->{'column'}."] ";
}

sub as_json {
	my ($self) = @_;

	tie my %r, "Tie::IxHash", (
		'action' => "hard-coded-lookup",
		'map' => $self->{'map'},
		'from_table' => $self->{'table'},
		'from_column' => $self->{'column'},
	);
	return \%r;
}

package Migration::Rule::ConstantValue;

use base qw(Migration::Rule);

sub new {
	my ($class, $value) = @_;
	
	my $self = bless {
		'value' => $value,
	}, $class;
	return $self;
}

sub as_string {
	my ($self) = @_;
	
	return "constant [".$self->{'value'}."]";
}

sub as_json {
	my ($self) = @_;

	tie my %r, "Tie::IxHash", (
		'action' => "constant",
		'value' => $self->{'value'},
	);
	return \%r;
}

package Migration::Rule::Eval;

use base qw(Migration::Rule);

sub new {
	my ($class, $eval, $table, $column) = @_;
	
	my $self = bless {
		'eval' => $eval,
		'table' => $table,
		'column' => $column,
	}, $class;
	return $self;
}

sub as_string {
	my ($self) = @_;
	
	return "eval [".$self->{'eval'}."]".(defined $self->{'table'} ? " value from [".$self->{'table'}.".".$self->{'column'}."]" : "");
}

sub as_json {
	my ($self) = @_;

	tie my %r, "Tie::IxHash", (
		'action' => "eval",
		'eval' => $self->{'eval'},
	);
	if (defined $self->{'table'}) {
		$r{'from_table'} = $self->{'table'};
		$r{'from_column'} = $self->{'column'};
	}
	return \%r;
}

