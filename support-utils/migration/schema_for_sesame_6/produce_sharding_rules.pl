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
	my $required_tables = get_required_tables($logger, "_table_sharding_migration.json");

	my $schema_6 = get_sesame_6_schema($logger);

	my $links = Links->new();
	load_links_from_model($logger, $links, "Unified DB.pdm");
	my $rules = get_schema_diff($logger, $schema_6, $required_tables, $links);
	$rules->save_json_to("_rules.json");
}

sub get_schema_diff {
	my ($logger, $schema_6_list, $required_tables, $links) = @_;

	my $schema_6 = group_by_columns($schema_6_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);

	my $migration = Migration->new($schema_6, $required_tables);
	$migration->load_hard_coded_links($links);
	$required_tables = filter_and_expand_required_tables($logger, $required_tables, $migration, ['1', '2', '3']);

	my %allowed_tables = map { $_->{'table'} => 1 } @$required_tables;
	$links->remove_link_not_from_tables(\%allowed_tables);
	$links->verify_broken_links($logger, \%allowed_tables, $migration);

	verify_links($logger, $links, $schema_6_list, \%allowed_tables, $migration);

	my $required = group_by_columns($required_tables, [ 'table' ]);

	my $rules = MigrationRules->new($logger, $schema_6_list, $required, $migration);

	$rules->apply_simple_columns_info($migration);
	$rules->apply_links($links, $migration);
	$rules->apply_table_info($migration, $links, $schema_6_list);
	$rules->apply_table_priority($migration, $required_tables);
	$rules->update_copy_columns_for_link();
	$rules->apply_missing_eval($migration, $links);
	$rules->generate_secondary_rules_for_date_filter($migration);
	
	$rules->save_json_to("_out.json", 1);
	$rules->save_html_to("_out.html");
	$rules->save_jira_to("_out.jira");


	#$rules->check_column_rules();
	return $rules;
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
			$tables_6{$table->{'table'}} = { %$table };
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
		"sms_message_response.client_id", "*.dataset_version_id", "pms_migration_remap.new_id", 
		"pms_migration_remap.old_id", "client_current_dataset.last_initial_version_id", 
		"client_current_dataset.last_last_initial_version_id" );
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
				! $migration->is_link_to_shared_table($column->{'TABLE_NAME'}, $column->{'COLUMN_NAME'}) 
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

	
	$links->delete_link_between_tables("appointment_confirmation_history", "appointment");
	$links->delete_link_between_tables("appointment_confirmation_history", "visitor");
	$links->delete_link_between_tables("appointment_reminder_schedule", "visitor");
	$links->delete_link_between_tables("appointment_user_sensitive", "appointment");
	$links->delete_link_between_tables("email_contact_log", "visitor");
	$links->delete_link_between_tables("email_post_app_survey_log", "visitor");
	$links->delete_link_between_tables("email_referral", "referrer");
	$links->delete_link_between_tables("email_sent_mail_log", "visitor");
	$links->delete_link_between_tables("email_welcome_forcing", "visitor");
	$links->delete_link_between_tables("flex_plan_info", "visitor");
	$links->delete_link_between_tables("hide_patient_change_history", "responsible_patient");
	$links->delete_link_between_tables("hits_log", "visitor");
	$links->delete_link_between_tables("insurance_plan_info", "visitor");
	$links->delete_link_between_tables("invisalign_patient", "visitor");
	$links->delete_link_between_tables("orthomation", "visitor");
	$links->delete_link_between_tables("ppn_article_letter", "ppn_common_article");
	$links->delete_link_between_tables("referrer_email_log", "referrer");
	$links->delete_link_between_tables("send2friend_log", "visitor");
	$links->delete_link_between_tables("si_doctor", "referrer");
	$links->delete_link_between_tables("si_patient_link", "visitor");
	$links->delete_link_between_tables("si_pms_referrer_link", "referrer");
	$links->delete_link_between_tables("si_theme", "si_message");
	$links->delete_link_between_tables("sms_message_history", "client");
	$links->delete_link_between_tables("sms_message_history", "visitor");
	$links->delete_link_between_tables("sms_message_response", "client");
	$links->delete_link_between_tables("staff_schedule", "office");
	$links->delete_link_between_tables("staff_schedule_rules", "office");
	$links->delete_link_between_tables("survey_answer", "visitor");
	$links->delete_link_between_tables("visitor_opinion", "office");
	$links->delete_link_between_tables("visitor_opinion", "visitor");
	$links->delete_link_between_tables("visitor_setting", "visitor");
	$links->delete_link_between_tables("visitor_settings", "visitor");
	$links->delete_link_between_tables("voice_appointment_reminder_procedure", "procedure");
	$links->delete_link_between_tables("voice_patient_name_pronunciation", "visitor");
	$links->delete_link_between_tables("voice_recipient_list", "visitor");

	#$links->delete_link_between_tables("referrer_email_log", "referrer");
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

sub apply_table_info {
	my ($self, $migration, $links, $schema_6) = @_;

	{
		my $stop = 0;
		for my $table (keys %{ $self->{'rules'} }) {
			my $table_action = $migration->get_table_action($table);
			my $table_filter = $migration->get_table_filter($table);
			tie my %r, 'Tie::IxHash', (
				'action' => $table_action,
				'filter' => $table_filter,
			);
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
		$self->{'tables'}{ $table->{'table'} }{'priority'} = $table->{'priority'};
		if (defined $table->{'filter'} && $table->{'filter'} ~~ ['past-week', 'past-week-only']) {
			my $date_column = $table->{'date column'};
			unless (defined $date_column) {
				die "no data column for [".$table->{'table'}."]";
			}

			my ($date_table, $column) = ($table->{'table'}, $date_column);
			if ($date_column =~ m{\.}) {
				($date_table, $column) = split(m{\.}, $date_column, 2);
			}
			$self->{'tables'}{ $table->{'table'} }{'date_filter_column'} = {
				'table' => $date_table,
				'column' => $column,
			};
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

sub generate_secondary_rules_for_date_filter {
    my ($self, $migration) = @_;

	my $column_rules = $self->{'rules'};
	for my $table_6 (keys %$column_rules) {
		if (defined $self->{'tables'}{$table_6}{'filter'} && $self->{'tables'}{$table_6}{'filter'} eq 'past-week') {
			if (exists $self->{'tables'}{$table_6.":2"}) {
				die "not unique date filter column rule id for [$table_6]";
			}
			tie my %new_tables, 'Tie::IxHash', %{ $self->{'tables'}{$table_6} };
			$self->{'tables'}{$table_6.":2"} = \%new_tables;
			tie my %new_rules, 'Tie::IxHash', %{ $self->{'rules'}{$table_6} };
			$self->{'rules'}{$table_6.":2"} = \%new_rules;
			if ($table_6 eq 'email_contact_log') {
				# fix insertContactLog
				$self->{'tables'}{$table_6.":2"}{'action'} = 'insert-contact-log';
			} else {
				$self->{'tables'}{$table_6.":2"}{'action'} = 'insert';
			}
			$self->{'tables'}{$table_6.":2"}{'filter'} = 'older-than-week';
			$self->{'tables'}{$table_6.":2"}{'priority'} = '3';

			$self->{'tables'}{$table_6}{'filter'} = 'past-week-only';
			$self->{'tables'}{$table_6}{'priority'} = '2';
		}
	}
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

	for my $table_6 (keys %{ $self->{'tables'} }) {
		tie my %r, 'Tie::IxHash', (
			'to_table' => _get_table_name($table_6),
			(exists $self->{'tables'}{$table_6} ? %{ $self->{'tables'}{$table_6} } : () ),
			'columns' => [],
		);
		$rules_by_table{$table_6} = \%r;
		my @missing_rules;
		for my $column_6 (keys %{ $column_rules->{$table_6} }) {
			my $rule = $column_rules->{$table_6}{$column_6};
			if (defined $rule) {
				if (defined $rule->as_json()) {
					my $column = $self->_make_json_column_obj($table_6, $column_6, $rule, $no_missing_rules);
					push(@{ $rules_by_table{$table_6}{'columns'} }, $column);
				}
			} else {
				push(@missing_rules, $column_6);
			}
		}
		# if (!$no_missing_rules && @missing_rules) {
		# 	for my $column_6 (@missing_rules) {
		# 		tie my %r, "Tie::IxHash", (
		# 			'table' => $table_6,
		# 			'column' => $column_6,
		# 		);
		# 		push(
		# 			@{ $rules_by_table{$table_6}{'columns'} },
		# 			\%r
		# 		);
		# 	}
		# }
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
		push(@lines, "<li>Table: <span class=\"value\">".$rules->{$table}{'to_table'}."</span></li>");
		push(@lines, "<li>Action: <span class=\"value\">".$rules->{$table}{'action'}."</span></li>");
		push(@lines, "<li>Priority: <span class=\"value\">".$rules->{$table}{'priority'}."</span></li>");
		if (defined $rules->{$table}{'filter'}) {
			push(@lines, "<li>Filter: <span class=\"value\">".$rules->{$table}{'filter'}."</span></li>");
		}
		my %update_columns;
		if ($rules->{$table}{'update_on'}) {
			%update_columns = map {$_ => 1} @{ $rules->{$table}{'update_on'} };
			push(@lines, "<li>Update on: ".join(", ", map {"<span class=\"value\">$_</span>"} @{ $rules->{$table}{'update_on'} })."</li>");
		}
		if ($rules->{$table}{'where'}) {
			push(@lines, "<li>Delete where: ".join(" AND ", map {"<span class=\"value\">$_ = ".$rules->{$table}{'where'}{$_}."</span>"} keys %{ $rules->{$table}{'where'} })."</li>");
		}
		if ($rules->{$table}{'path_to_client'} && @{ $rules->{$table}{'path_to_client'} }) {
			$update_columns{ $rules->{$table}{'path_to_client'}->[0]{'column'} } = 1;
			push(@lines, "<li>Path to client: ".join(" &gt; ", map {"<span class=\"value\">".$_->{'table'}.".".$_->{'column'}."</span>"} @{ $rules->{$table}{'path_to_client'} })."</li>");
		}
		if ($rules->{$table}{'date_filter_column'}) {
			$update_columns{$rules->{$table}{'date_filter_column'}} = 1;
			push(@lines, "<li>Date column: <span class=\"value\">".$rules->{$table}{'date_filter_column'}{'table'}
				.".".$rules->{$table}{'date_filter_column'}{'column'}."</span></li>");
		}
		push(@lines, "</ul>");
		if (exists $rules->{$table}{'columns'} && @{ $rules->{$table}{'columns'} }) {
			push(@lines, "<table><tr><th>column</th><th>action</th></tr>");
			for my $column ($self->_sort_column_names( $rules->{$table}{'columns'} ) ) {
				push(@lines, "<tr><td><a name=\"column.".$rules->{$table}{'to_table'}.".".$column->{'column'}."\"></a>".
					_html_highlight($column->{'column'}, $update_columns{$column->{'column'}}, 'value')."</td>");
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
		if (defined $rules->{$table}{'filter'}) {
			push(@lines, "* Filter: *".$rules->{$table}{'filter'}."*");
		}
		my %update_columns;
		if ($rules->{$table}{'update_on'}) {
			%update_columns = map {$_ => 1} @{ $rules->{$table}{'update_on'} };
			push(@lines, "* Update on: ".join(", ", map {"*$_*"} @{ $rules->{$table}{'update_on'} }));
		}
		if ($rules->{$table}{'path_to_client'} && @{ $rules->{$table}{'path_to_client'} }) {
			$update_columns{ $rules->{$table}{'path_to_client'}->[0]{'column'} } = 1;
			push(@lines, "* Path to client: ".join(" > ", map {"*".$_->{'table'}.".".$_->{'column'}."*"} @{ $rules->{$table}{'path_to_client'} }));
		}
		if ($rules->{$table}{'date_filter_column'}) {
			$update_columns{$rules->{$table}{'date_filter_column'}} = 1;
			push(@lines, "*Date column: *".$rules->{$table}{'date_filter_column'}{'table'}.".".$rules->{$table}{'date_filter_column'}{'column'}."*");
		}
		push(@lines, "");
		if (exists $rules->{$table}{'columns'} && @{ $rules->{$table}{'columns'} }) {
			push(@lines, "|| column || action ||");
			for my $column ($self->_sort_column_names( $rules->{$table}{'columns'} ) ) {
				my @row;
				push(@row, _jira_highlight($column->{'column'}, $update_columns{$column->{'column'}}));
				if (exists $column->{'action'}) {
					if ($column->{'action'} eq "copy" && $rules->{$table}{'action'} eq 'remap-only') {
						push(@row, $rules->{$table}{'action'});
					} elsif ($column->{'action'} eq "foreign-key") {
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

			# if ($migration->is_column_from_pms($table_6, $column_6)) {
			# 	return Migration::Rule::FromPMS->new();
			# } 
			if ($migration->is_column_autoincrement($table_6, $column_6)) {
				return Migration::Rule::AutoIncrement->new();
			}
			# if ($migration->is_constant_value_exists($table_6, $column_6)) {
			# 	return Migration::Rule::ConstantValue->new($migration->get_constant_value($table_6, $column_6));
			# }
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
				if (ref $rule eq 'Migration::Rule::AutoIncrement') {
					## autoincrement values will be saved
				} else {
					if (defined $rule) {
						die "can't override rule with copy-and-save ".ref($rule);
					}
					$rule = Migration::Rule::CopyAndSaveValue->new(
						$table_6, 
						$column_6
					);
					$self->{'logger'}->printf("%s.%s <- %s", $table_6, $column_6, $rule->as_string());
				}
			}
			return $rule;
		}
	);
	if ($self->{'rules'}{"voice_left_messages"}{"call_id"}) {
		die "can't set copy-and-save on existing rule [voice_left_messages.call_id]";
	}
	$self->{'rules'}{"voice_left_messages"}{"call_id"} = Migration::Rule::CopyAndSaveValue->new(
		"voice_left_messages", 
		"call_id"
	);
	$self->{'rules'}{"voice_system_transaction_log"}{"voice_queue_id"} = Migration::Rule::CopyAndSaveValue->new(
		"voice_system_transaction_log", 
		"voice_queue_id"
	);;

}

# sub update_copy_columns_for_eval {
#     my ($self, $migration) = @_;

#     my $stop = 0;
# 	$self->_for_each_rule(
# 		sub {
# 		    my ($table_6, $column_6, $rule) = @_;
			
# 			if ($migration->get_need_convert_datetime($table_6, $column_6)) {
# 				if (ref $rule eq 'Migration::Rule::CopyValue') {
# 					return Migration::Rule::Eval->new(
# 						'convert-time-zone-from-'.$migration->get_need_convert_datetime($table_6, $column_6), 
# 						$rule->{'table'},
# 						$rule->{'column'}
# 					);
# 				} else {
# 					$self->{'logger'}->printf("%s.%s:can't apply datetime convertion to [%s] ", $table_6, $column_6, ref($rule));
# 					$stop ++;
# 				}
# 			}
# 			return undef;
# 		}
# 	);
# 	$self->{'logger'}->stop($stop, "columns with unexpected rules for time zone convertion");
# }

sub apply_missing_eval {
	my ($self, $migration, $links) = @_;
	
	# $self->_for_each_undefinded_rule(
	# 	sub {
	# 		my ($table_6, $column_6) = @_;

	# 		my $eval = $migration->get_column_eval($table_6, $column_6, $links);
	# 		if (defined $eval) {
	# 			return Migration::Rule::Eval->new($eval->{'eval'}, undef, undef);
	# 		}
	# 		return undef;
	# 	}
	# );

	## hard-coded evals

	# ## eval for active office id
	# $self->{'rules'}{'office_user_sensitive:2'}{'active'} = Migration::Rule::Eval->new('office-active', undef, undef);
	# delete $self->{'rules'}{'office_user_sensitive'}{'active'};
	# $self->{'tables'}{'office_user_sensitive:2'} = { %{ $self->{'tables'}{'office_user_sensitive'} } };
	# $self->{'tables'}{'office_user_sensitive:2'}{'action'} = 'update-office-active';

	# $self->{'rules'}{'office_user_sensitive:3'}{'name_local'} = Migration::Rule::Eval->new('office-local-name', undef, undef);
	# delete $self->{'rules'}{'office_user_sensitive'}{'name_local'};
	# $self->{'tables'}{'office_user_sensitive:3'} = { %{ $self->{'tables'}{'office_user_sensitive'} } };
	# $self->{'tables'}{'office_user_sensitive:3'}{'action'} = 'update-office-local-name';

	# $self->{'rules'}{'referrer_user_sensitive'}{'si_doctor_id'} = Migration::Rule::Eval->new('si-doctor-id', 'si_pms_referrer_link', 'referrer_id');
	# $self->{'rules'}{'si_doctor_email_log'}{'si_doctor_id'} = Migration::Rule::Eval->new('si-doctor-referrer-id', 'si_doctor_email_log_fake', 'referrer_id');

	# ## eval for si auto notify
	# $self->{'rules'}{'client_setting:4'}{'IVal'} = Migration::Rule::Eval->new('voice-client-id', undef, undef);
	# $self->{'tables'}{'client_setting:4'} = { %{ $self->{'tables'}{'client_setting'} } };
	# $self->{'tables'}{'client_setting:4'}{'action'} = 'update-voice-client-id';

	# ## eval for missing si colleague
	# $self->{'rules'}{'si_doctor:2'}{'Status'} = Migration::Rule::Eval->new('missing-si-admin-id', undef, undef);
	# $self->{'tables'}{'si_doctor:2'} = { %{ $self->{'tables'}{'si_doctor'} } };
	# $self->{'tables'}{'si_doctor:2'}{'action'} = 'add-missing-si-admin';

	# ## fix ppn_article_letter:2 link
	# $self->{'rules'}{'ppn_article_letter:2'}{'let_id'} = Migration::Rule::ForeignKey->new('ppn_letter', 'id', 'ppn_article_letter_common_fake', 'let_id')->set_source("special hard-code");

	# ## fix constant text in email_reminder settings
	# $self->{'rules'}{'email_reminder_settings:3'}{'body'} = Migration::Rule::Eval->new('prepend-constant-text', undef, undef);
	# $self->{'tables'}{'email_reminder_settings:3'} = { %{ $self->{'tables'}{'email_reminder_settings'} } };
	# $self->{'tables'}{'email_reminder_settings:3'}{'action'} = 'update-prepend-constant-text';

	# ## fix website analytics feature
	# $self->{'rules'}{'client_feature:2'}{'is_enabled'} = Migration::Rule::Eval->new('website-analytics-feature', undef, undef);
	# $self->{'tables'}{'client_feature:2'} = { %{ $self->{'tables'}{'client_feature'} } };
	# $self->{'tables'}{'client_feature:2'}{'action'} = 'update-website-analytics-feature';

	## skip nullable patient_id in invisalign_patient
	#$self->{'rules'}{'invisalign_patient'}{'patient_id'}->ignore_null();

	## eval for voice end message id
	$self->{'tables'}{'client_setting:2'} = { %{ $self->{'tables'}{'client_setting'} } };
	$self->{'tables'}{'client_setting:2'}{'action'} = 'update-voice-end-message-id';

	## eval for first si theme message id
	$self->{'tables'}{'si_theme:2'} = { %{ $self->{'tables'}{'si_theme'} } };
	$self->{'tables'}{'si_theme:2'}{'action'} = 'update-first-theme-message-id';

	$self->{'rules'}{'si_client_settings'}{'last_log_report_id'}->ignore_null();
	$self->{'rules'}{'si_client_settings'}{'last_successful_log_report_id'}->ignore_null();
	$self->{'rules'}{'si_client_settings'}{'last_modules_log_report_id'}->ignore_null();
	
	$self->{'rules'}{'ppn_article_letter'}{'art_id'}->set_ppn_article();

	#$self->{'rules'}{'visitor_versioned'}{'address_id'}->ignore_null();
}

sub apply_links {
	my ($self, $links, $migration) = @_;
	
	$self->_for_each_undefinded_rule(
		sub {
			my ($table_6, $column_6) = @_;

			my $link = $links->get_link_from($table_6, $column_6);
			if (defined $link && ! $migration->is_link_to_shared_table($table_6, $column_6)) {
				if ($migration->is_table_with_stable_id($link->{'to_table'})) {
					## no need to generate rule if link is stable
				} else {
					my $link_info = $link->{'link_info'} // {};
					return Migration::Rule::ForeignKey->new(
						$link->{'to_table'}, 
						$link->{'to_column'}, 
						$link_info->{'table'}, 
						$link_info->{'column'}
					)->set_source($link->{'comment'});
				}
			}
			return undef;
		}
	);
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
					if ($migration->is_link_to_shared_table($from_table, $from_column_str)) {
						## ignore lookups
					} else {
						my $comment = join ', ', values %{ $self->{'comments'}{$from_table}{$to_table} };
						push(@stop, sprintf("table [%s] was removed, but link is in [%s.%s] (%s)", $to_table, $from_table, $from_column_str, $comment));
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

	my $self = bless {
		'update_on' => {
			'client' => ['cl_username'],
			'client_setting' => ['client_id', 'PKey'],
			'email_reminder_settings' => ['client_id', 'type'],
			'srm_resource' => ['id'],
			'upload_settings' => ['client_id', 'name'],
			'sms_client_settings' => ['client_id'],
			'client_feature' => ['client_id', 'feature_id'],
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
			'invisalign_patient' => [
	            {
	                "table" => "invisalign_patient",
	                "column" => "invisalign_client_id",
	            },
	            {
	                "table" => "invisalign_client",
	                "column" => "client_id",
	            },
			],
		},
		'link_to_shared_table' => {
			'client.client_edition_id' => 1,
			'client.pms_software_id' => 1,
			'client_feature.feature_id' => 1,
			'email_reminder_settings.design_id' => 1,
			'email_sending_queue.design_id' => 1,
			'hits_count.hcount_sect_id' => 1,
			'hits_log.hlog_sect_id' => 1,
			'holiday_delivery_log.hd_id' => 1,
			'holiday_delivery_log.hdc_id' => 1,
			'holiday_settings.hd_id' => 1,
			'holiday_settings.hdc_id' => 1,
			'holiday_settings_recipients_link.hr_id' => 1,
			'holiday_settings_recipients_link_log.hr_id' => 1,
			'orthomation.node_id' => 1,
			'pms_migration_status.new_pms_software_id' => 1,
			'ppn_article_queue.art_id' => 1,
			'ppn_common_article_usage.art_id' => 1,
			'ppn_letter_logo.logo_id' => 1,
			'si_client_settings.si_image_system_id' => 1,
			'si_client_task.si_standard_task_id' => 1,
			'si_upload_log_report.server_id' => 1,
			'survey_question.client_edition_id' => 1,
			'upload_postprocessing_task.postprocessing_action_id' => 1,
			'visitor_opinion.category_id' => 1,
		},
		'tables_with_stable_ids' => {
			'account_versioned' => 1,
			'address_versioned' => 1,
			'appointment_procedure_versioned' => 1,
			'appointment_versioned' => 1,
			'client' => 1,
			'email_versioned' => 1,
			'insurance_contract_versioned' => 1,
			'ledger_versioned' => 1,
			'office_versioned' => 1,
			'patient_referrer_versioned' => 1,
			'patient_staff_versioned' => 1,
			'phone_versioned' => 1,
			'procedure_versioned' => 1,
			'recall_versioned' => 1,
			'referrer_versioned' => 1,
			'responsible_patient_versioned' => 1,
			'staff_versioned' => 1,
			'treatment_plan_versioned' => 1,
			'visitor_versioned' => 1,
		}
	}, $class;
	$self->_generate_actions($required_tables);
	$self->_generate_filters($required_tables);
	$self->_generate_autoincrement($schema_6);
	return $self;
}

sub get_table_name {
	my ($self, $table) = @_;

	unless (defined $table) {
		die "table name can't be undef";
	}
	
	$table =~ s{:.*$}{};
	return $table;
}

sub _generate_actions {
	my ($self, $required_tables) = @_;
	
	my %know_actions = map {$_ => 1} ("delete-insert", "insert");
	my %actions;
	for my $table (@$required_tables) {
		$table->{'action'} //= '';
		if (exists $know_actions{$table->{'action'}}) {
			$actions{$table->{'table'}} = $table->{'action'};
		} elsif (!$table->{'action'}) {
			## ignore empty actions by now
		} else {
			die "unknown action [".$table->{'action'}."]";
		}
	}
	$self->{'actions'} = \%actions;
}

sub _generate_filters {
	my ($self, $required_tables) = @_;
	
	my %know_filters = map {$_ => 1} ("versioned", "past-week", "past-week-only");
	my %filters;
	for my $table (@$required_tables) {
		$table->{'filter'} //= '';
		if (exists $know_filters{$table->{'filter'}}) {
			$filters{$table->{'table'}} = $table->{'filter'};
		} elsif (!$table->{'filter'}) {
			## ignore empty
		} else {
			die "unknown filter [".$table->{'filter'}."]";
		}
	}
	$self->{'filters'} = \%filters;
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

# sub _get_versioned_name_base {
# 	my ($self, $name) = @_;
	
# 	if ($name =~ m{^(.*)_versioned$}) {
# 		return $1;
# 	} else {
# 		return undef;
# 	}
# }

sub is_column_autoincrement {
	my ($self, $table_6, $column_6) = @_;

	$table_6 = $self->get_table_name($table_6);
	return $self->{'autoincrement'}{$table_6}{$column_6};
}

sub is_link_to_shared_table {
	my ($self, $table_6, $column_6) = @_;

	return exists $self->{'link_to_shared_table'}{$table_6.".".$column_6};
}

sub is_table_with_stable_id {
    my ($self, $to_table) = @_;
	
	return $self->{'tables_with_stable_ids'}{$to_table};
}

sub get_path_to_client {
	my ($self, $table_6) = @_;

	return $self->{'path_to_client'}{$table_6};
}

sub get_table_action {
	my ($self, $table_6) = @_;
	
	if (exists $self->{'actions'}{$table_6}) {
		return $self->{'actions'}{$table_6};
	} else {
		die "can't find action for [$table_6]";
	}
}

sub get_table_filter {
	my ($self, $table_6) = @_;
	
	return $self->{'filters'}{$table_6};
}

sub load_hard_coded_links {
	my ($self, $links) = @_;

	## client_id
	for my $from_table (
		"appointment_reminder_schedule", "email_contact_log", "email_sent_mail_log", "upload_settings", 
		"address_local", "email_local", "office_address_local", "patient_page_messages", "phone_local", "referrer_local",
		"email_referral_mail", "ppn_article_letter", "email_referral", "voice_recipient_list", "referrer_email_log",
		"referrer_user_sensitive", "si_doctor_email_log", "email_welcome_forcing", 
		"account_versioned", "address_versioned", "appointment_procedure_versioned", "appointment_versioned", 
		"email_versioned", "insurance_contract_versioned", "ledger_versioned", "office_versioned", 
		"patient_referrer_versioned", "patient_staff_versioned", "phone_versioned", "procedure_versioned", 
		"recall_versioned", "referrer_versioned", "responsible_patient_versioned", "staff_versioned", 
		"treatment_plan_versioned", "visitor_versioned", "appointment_local", "email_user_sensitive", 
		"office_user_sensitive", "phone_user_sensitive", "procedure_user_sensitive", "recall_user_sensitive", 
		"responsible_patient_user_sensitive", "visitor_fact", "visitor_user_sensitive", "client_current_dataset",
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
		"opse_payment_log.patient_id", "token.user_id", "appointment_confirmation_history.patient_id", "appointment_reminder_schedule.client_id",
		"email_contact_log.visitor_id", "email_post_app_survey_log.patient_id", "email_sent_mail_log.visitor_id",
		"flex_plan_info.visitor_id", "hits_log.visitor_id", "insurance_plan_info.patient_id", "invisalign_patient.patient_id",
		"orthomation.patient_id", "send2friend_log.patient_id", "si_patient_link.patient_id", "sms_message_history.patient_id",
		"survey_answer.visitor_id", "visitor_opinion.visitor_id", "visitor_setting.visitor_id", "visitor_settings.visitor_id",
		"voice_patient_name_pronunciation.patient_id", "voice_recipient_list.patient_id", "account_versioned.responsible_patient_id", 
		"address_local.visitor_id", "appointment_local.patient_id", "appointment_versioned.patient_id", "email_local.visitor_id", 
		"email_versioned.visitor_id", "patient_referrer_versioned.patient_id", "patient_staff_versioned.patient_id", 
		"phone_local.visitor_id", "phone_versioned.visitor_id", "recall_versioned.patient_id", 
		"responsible_patient_versioned.patient_id", "treatment_plan_versioned.patient_id", "email_patient_access_token.visitor_id",

	) {
		my ($from_table, $from_column) = split('\.', $link);
		$links->add_link(
			$from_table, 
			"visitor_versioned", 
			{
				$from_column => "id",
			},
			"hard-coded",
		);
	}

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

	# $links->add_link(
	# 	'email_user_sensitive', 
	# 	'email_versioned', 
	# 	{
	# 		'email_id' => "id",
	# 	},
	# 	"hard-coded",
	# 	{
	# 		'table' => 'email',
	# 		'column' => 'pms_id',
	# 	}
	# );
	# $links->add_link(
	# 	'phone_user_sensitive', 
	# 	'phone_versioned', 
	# 	{
	# 		'phone_id' => "id",
	# 	},
	# 	"hard-coded",
	# 	{
	# 		'table' => 'phone',
	# 		'column' => 'pms_id',
	# 	}
	# );
	## other
	$links->add_links(
		{
			'account_versioned.insurance_contract_id' => 'insurance_contract_versioned.id',
			'appointment_confirmation_history.appointment_id' => 'appointment_versioned.id',
			'appointment_local.office_id' => 'office_versioned.id',
			'appointment_local.staff_id' => 'staff_versioned.id',
			'appointment_procedure_versioned.appointment_id' => 'appointment_versioned.id',
			'appointment_procedure_versioned.procedure_id' => 'procedure_versioned.id',
			'appointment_user_sensitive.appointment_id' => 'appointment_versioned.id',
			'appointment_versioned.office_id' => 'office_versioned.id',
			'appointment_versioned.staff_id' => 'staff_versioned.id',
			'client_access.user_name' => 'client.cl_username',
			'email_referral.referral_mail_id' => 'email_referral_mail.id',
			'email_referral.referrer_id' => 'visitor_versioned.id', ## type column is in fact 'visitor' for all records
			'hide_patient_change_history.responsible_patient_id' => 'responsible_patient_versioned.id',
			'invisalign_case_process_patient.invisalign_client_id' => 'invisalign_client.id',
			'ledger_versioned.account_id' => 'account_versioned.id',
			'office_address_local.office_id' => 'office_versioned.id',
			'office_versioned.address_id' => 'address_versioned.id',
			'orthomation.node_id' => 'orthomation_nodes.node_id',
			'patient_referrer_versioned.referrer_id' => 'referrer_versioned.id',
			'patient_staff_versioned.staff_id' => 'staff_versioned.id',
			'recall_versioned.office_id' => 'office_versioned.id',
			'referrer_email_log.referrer_id' => 'referrer_versioned.id',
			'referrer_user_sensitive.si_doctor_id' => 'si_doctor.DocId',
			'referrer_versioned.si_doctor_id' => 'si_doctor.DocId',
			'responsible_patient_versioned.responsible_id' => 'visitor_versioned.id',
			'si_doctor_email_log.si_doctor_id' => 'si_doctor.DocId',
			'srm_resource.container' => 'client.cl_username',
			'staff_schedule.office_id' => 'office_versioned.id',
			'staff_schedule_rules.office_id' => 'office_versioned.id',
			'treatment_plan_versioned.procedure_id' => 'procedure_versioned.id',
			'visitor_opinion.category_id' => 'review_category.id',
			'visitor_opinion.office_id' => 'office_versioned.id',
			'visitor_versioned.address_id' => 'address_versioned.id',
			'voice_appointment_reminder_procedure.procedure_id' => 'procedure_versioned.id',
			'voice_left_messages.rec_id' => 'voice_recipient_list.RLId',
			'voice_message_history.rec_id' => 'voice_recipient_list.RLId',
		},
		"hard-coded",
	);
	## user sensitive
	my %user_sensitive_links = (
		'email_user_sensitive.email_id' => 'email_versioned',
		'phone_user_sensitive.phone_id' => 'phone_versioned',
		'procedure_user_sensitive.procedure_id' => 'procedure_versioned',
		'recall_user_sensitive.recall_id' => 'recall_versioned',
		'responsible_patient_user_sensitive.responsible_patient_id' => 'responsible_patient_versioned',
		'visitor_user_sensitive.visitor_id' => 'visitor_versioned',
		'referrer_user_sensitive.referrer_id' => 'referrer_versioned',
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

# sub restore_remap_only_links {
# 	my ($self, $links) = @_;
	
# 	$links->add_links(
# 		{
# 			'address_versioned.client_id' => 'client.id',
# 			'appointment_versioned.client_id' => 'client.id',
# 			'email_versioned.client_id' => 'client.id',
# 			'office_versioned.client_id' => 'client.id',
# 			'phone_versioned.client_id' => 'client.id',
# 			'procedure_versioned.client_id' => 'client.id',
# 			'recall_versioned.client_id' => 'client.id',
# 			'responsible_patient_versioned.client_id' => 'client.id',
# 			'staff_versioned.client_id' => 'client.id',
# 			'visitor_versioned.client_id' => 'client.id',
# 		},
# 		"remap-only",
# 	);
# }


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
		# 'from_table' => $from_table,
		# 'from_column' => $from_column,
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
		'action' => "foreign-key".($self->{'ignore_null'} ? "-skip-null" : "").($self->{'ppn'} ? "-ppn" : ""),
		'lookup_table' => $self->{'table'},
		'lookup_column' => $self->{'column'},
	);
	if (defined $self->{'from_table'}) {
		# $r{'from_table'} = $self->{'from_table'};
		# $r{'from_column'} = $self->{'from_column'};
	}
	return \%r;
}

sub ignore_null {
    my ($self) = @_;
	
	$self->{'ignore_null'} = 1;
}

sub set_ppn_article {
    my ($self) = @_;
	
	$self->{'ppn'} = 1;
}

package Migration::Rule::CopyAndSaveValue;

use base qw(Migration::Rule);

sub new {
	my ($class, $table, $column) = @_;
	
	my $self = bless {
		'table' => $table,
		'column' => $column,
		'action' => 'copy-and-save',
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
		# 'from_table' => $self->{'table'},
		# 'from_column' => $self->{'column'},
	);
	return \%r;
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
