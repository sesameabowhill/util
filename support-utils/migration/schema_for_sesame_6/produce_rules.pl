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
	load_hard_coded_links($links);
	get_schema_diff($logger, $schema_5, $schema_6, $required_tables, $links);
}

sub get_schema_diff {
    my ($logger, $schema_5_list, $schema_6_list, $required_tables, $links) = @_;

	my $schema_5 = group_by_columns($schema_5_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);
	my $schema_6 = group_by_columns($schema_6_list, [ 'TABLE_NAME', 'COLUMN_NAME' ]);

    my $migration = Migration->new($schema_6, $required_tables);
    $required_tables = filter_and_expand_required_tables($logger, $required_tables, $migration, ['1', '2', '3']);

    $links->rename_tables($migration, $schema_6);
    my %allowed_tables = map { $_->{'table'} => 1 } @$required_tables;
	$links->remove_link_not_from_tables(\%allowed_tables);
	$links->verify_broken_links($logger, \%allowed_tables, $migration);

	verify_links($logger, $links, $schema_6_list, \%allowed_tables, $migration);

	check_removed_tables($logger, $migration, $schema_5, $schema_6);
	my $required = group_by_columns($required_tables, [ 'table' ]);

	my $rules = MigrationRules->new($logger, $schema_6_list, $required);

	$rules->apply_table_info($migration);
	$rules->apply_simple_columns_info($migration);
	$rules->apply_links($links);
	$rules->apply_moved_tables($migration, $schema_5_list, $schema_6);
	
	$rules->save_json_to("_out.json", 1);
	$rules->save_html_to("_out.html");


	$rules->check_column_rules();
	return $rules->flat_rules();
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
		"*.pms_id", "*.link_id", "*.voice_queue_id", "*.clog_mail_id", "*.rec_id", "*.sml_mail_id", 
		"*.vip_patient_id", "invisalign_text.page_id", "si_image.is_id" );
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
						$logger->printf("link for [".$column->{'TABLE_NAME'}.".".$column->{'COLUMN_NAME'}."] is not found");
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
			}
		);
	}
	$links->delete_link_between_tables("appointment_reminder_schedule", "client");
}

sub load_hard_coded_links {
    my ($links) = @_;

	## client_id
	for my $from_table (
		"appointment_reminder_schedule", "email_contact_log", "email_sent_mail_log", "upload_settings", 
		"address_local", "email_local", "office_address_local", "patient_page_messages", "phone_local"
	) {
		$links->add_link(
			$from_table, 
			"client", 
			{
				'client_id' => "id",
			}
		);
	}

	## visitor_id
	for my $link (
		"address_local.visitor_id", "email_local.visitor_id", "phone_local.visitor_id", 
		"opse_payment_log.patient_id", "token.user_id"
	) {
		my ($from_table, $from_column) = split('\.', $link);
		$links->add_link(
			$from_table, 
			"visitor", 
			{
				$from_column => "id",
			}
		);
	}

	## other
	my %links = (
		'email_referral.referral_mail_id' => 'email_referral_mail.id',
		'invisalign_case_process_patient.invisalign_client_id' => 'invisalign_client.id',
		'office_address_local.office_id' => 'office.id',
		'orthomation.node_id' => 'orthomation_nodes.node_id',
		'visitor_opinion.category_id' => 'review_category.id',
		## user sensitive
		'email_user_sensitive.email_id' => 'email.id',
		'phone_user_sensitive.phone_id' => 'phone.id',
		'procedure_user_sensitive.procedure_id' => 'procedure.id',
		'recall_user_sensitive.recall_id' => 'recall.id',
		'responsible_patient_user_sensitive.responsible_patient_id' => 'responsible_patient.id',
		'visitor_user_sensitive.visitor_id' => 'visitor.id',
	);
	while (my ($from, $to) = each %links) { 
		my ($from_table, $from_column) = split('\.', $from, 2);
		my ($to_table, $to_column) = split('\.', $to, 2);
		$links->add_link(
			$from_table, 
			$to_table, 
			{
				$from_column => $to_column,
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
    my ($self, $migration) = @_;

	$self->{'remap_only_tables'} = $migration->get_tables_with_remap_only_action();

    my %remap_only_tables = map { $_ => 1 } @{ $self->{'remap_only_tables'} };
	for my $table (keys %{ $self->{'rules'} }) {
		if (exists $remap_only_tables{$table}) {
			die "rules found for remap-only table [$table]";
		}
		$self->{'tables'}{$table} = {
			'action' => $migration->get_table_action($table),
		};
	}
}

sub flat_rules {
    my ($self, $no_missing_rules) = @_;

    my $column_rules = $self->{'rules'};

    tie my %rules_by_table, "Tie::IxHash";

	for my $table_6 (@{ $self->{'remap_only_tables'} }) {
		$rules_by_table{$table_6} = {
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
			]
		};
	}    

	for my $table_6 (keys %$column_rules) {
		my @missing_rules;
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

sub _make_json_column_obj {
    my ($self, $table_6, $column_6, $rule, $no_missing_rules) = @_;
	
	tie my %r, "Tie::IxHash", (
		'table' => $table_6,
		'column' => $column_6,
		'comment' => $rule->as_string(),
		($no_missing_rules ? () : ( '_ref' => ref $rule )),
		%{ $rule->as_json() },
	);
	return \%r;
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
    	".error { color: #f00; font-weight: bold; }",
    	"th {text-align: left; }",
    	"</style></head><body>");
    for my $table (keys %$rules) {
    	push(@lines, "<h2><a name=\"table.".$table."\"></a>Table [$table]</h2>");
		push(@lines, "<p>Action: ".$rules->{$table}{'action'}."</p>");
    	if (exists $rules->{$table}{'columns'}) {
        	push(@lines, "<table><tr><th>column</th><th>from</th><th>action</th></tr>");
	    	for my $column ($self->_sort_column_names( $rules->{$table}{'columns'} ) ) {
		    	push(@lines, "<tr><td><a name=\"column.".$column->{'table'}.".".$column->{'column'}."\"></a>".$column->{'column'}."</td>");
		    	push(
	    			@lines, 
	    			"<td>".( $column->{'from_table'} ? 
	    				_html_highlight($column->{'from_table'}, $column->{'from_table'} ne $column->{'table'}) . "." . 
	    				_html_highlight($column->{'from_column'}, $column->{'from_column'} ne $column->{'column'}) :
	    				""
					)."</td>"
				);
				if (exists $column->{'action'}) {
					if ($column->{'action'} eq "foreign-key") {
						push(@lines, "<td>value from [<a href=\"#table.".$column->{'lookup_table'}."\">".$column->{'lookup_table'}."</a>.".
							"<a href=\"#column.".$column->{'lookup_table'}.".".$column->{'lookup_column'}."\">".$column->{'lookup_column'}."</a>]</td></tr>");
					} else {
						push(@lines, "<td>"._html_highlight($column->{'comment'}, $column->{'_ref'} !~ m{(?:Copy|Move)Value$}) ."</td></tr>");
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
		    } 
		    if ($migration->is_column_autoincrement($table_6, $column_6)) {
		    	return Migration::Rule::AutoIncrement->new();
			}
			if ($migration->is_constant_value_exists($table_6, $column_6)) {
				return Migration::Rule::ConstantValue->new($migration->get_constant_value($table_6, $column_6));
			}
			{
				my $hardcoded_lookup = $migration->get_hardcoded_lookup($table_6, $column_6);
				if (defined $hardcoded_lookup) {
					return Migration::Rule::HardCodedLookup->new($hardcoded_lookup);
				}
			}
			{
				my $conditional_lookup = $migration->get_conditional_lookup($table_6, $column_6);
				if (defined $conditional_lookup) {
					return Migration::Rule::ConditionalLookup->new($conditional_lookup);
				}
			}

			return undef;
		}
	);
}

sub apply_links {
    my ($self, $links) = @_;
	
    $self->_for_each_undefinded_rule(
		sub {
		    my ($table_6, $column_6) = @_;

		    my $link = $links->get_link_from($table_6, $column_6);
		    if (defined $link) {
		    	return Migration::Rule::ForeignKey->new($link->{'to_table'}, $link->{'to_column'});
		    }
			return undef;
		}
	);
}

sub apply_moved_tables {
    my ($self, $migration, $schema_5_list, $schema_6) = @_;

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
					if ($self->can_copy_type(\$stop, $migration, $column, $schema_6->{$new_name}{$new_column})) {
						if ($new_name eq $column->{'TABLE_NAME'}) {
							$column_rules->{$new_name}{$new_column} = Migration::Rule::MoveValue->new(
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
		if (lc $to_column->{'IS_NULLABLE'} eq 'no' || ! $migration->is_nullable_ignored($to_column->{'TABLE_NAME'}, $to_column->{'COLUMN_NAME'})) {
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
	}, $class;
	return $self;
}

sub add_link {
    my ($self, $from_table, $to_table, $columns) = @_;

    if ($self->is_link_exists($from_table, $to_table, $columns)) {
		die "link [$from_table] -> [$to_table] on [".$self->_columns_to_string($columns)."] is already defined";
	}
	$self->{'links'}{$from_table}{$to_table}{ _columns_key($columns) } = $columns;
}

sub _columns_key {
	my ($columns) = @_;

	return join("|", sort keys %$columns);
}

sub is_link_exists {
    my ($self, $from_table, $to_table, $columns) = @_;

	return exists $self->{'links'}{$from_table}{$to_table}{ _columns_key($columns) };
}

sub is_link_exists_from_column_to_table {
    my ($self, $from_table, $from_column, $to_table) = @_;
	
	return exists $self->{'links'}{$from_table}{$to_table}{$from_column};
}

sub is_link_exists_from_column {
    my ($self, $from_table, $from_column) = @_;
	
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
	
	return exists $self->{'links'}{$from_table}{$to_table};
}

sub get_link_from {
    my ($self, $from_table, $from_column) = @_;

    if (exists $self->{'links'}{$from_table}) {
    	for my $to_table (keys %{ $self->{'links'}{$from_table} }) {
    		my $links = $self->{'links'}{$from_table}{$to_table};
    		for my $link_info (values %$links) {
    			if (exists $link_info->{$from_column}) {
    				return {
    					'to_table' => $to_table,
    					'to_column' => $link_info->{$from_column},
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
						$links{$new_from_table}{ $migration->table_name_after_renamed($to_table) } = $new_link_info;
					}
				}
			}
		}
	}
	$self->{'links'} = \%links;
}

sub delete_link_between_tables {
    my ($self, $from_table, $to_table) = @_;

    delete $self->{'links'}{$from_table}{$to_table};
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
		'renamed' => {
			'appointment_extension' => 'appointment_versioned',
			'email_sent_mail_log_archive' => 'email_sent_mail_log',
			'voice_office_name_pronunciation' => 'office_user_sensitive',
			'patient_pages_message' => 'patient_page_messages',
			'referrer' => 'referrer_local',
			'address_visitor_fake' => 'address_local',
			'address_office_fake' => 'office_address_local',
			'email_local_fake' => 'email_local',
			'phone_local_fake' => 'phone_local',
			'referrer_local_fake' => 'referrer_local',
		},
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
			'referrer_local' => {
				'type' => 'referrer-type',
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
		},
		'conditional_lookup' => {
			'ppn_article_letter' => {
				'art_id' => 'newsletter-conditional-article-id',
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
		},
		'ignore_type_change' => {
			'appointment_confirmation_history' => {
				'client_id' => 1,
			},
			'client' => {
				'cl_start_date' => 1,
			},
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
		},
	}, $class;
	$self->_generate_versioned_rules($schema_6, $required_tables);
	$self->_generate_actions($required_tables);
	$self->_generate_autoincrement($schema_6);
	return $self;
}

sub _generate_actions {
    my ($self, $required_tables) = @_;
	
	my %know_actions = map {$_ => 1} ("delete-insert", "insert", "update", "update-insert", "remap-only");
	my %actions;
	for my $table (@$required_tables) {
		if ($table->{'action'} eq "referrer") {
			## TODO
			$actions{$table->{'table'}} = "???";
			$actions{$table->{'table'}."_local"} = "???";
		} elsif ($table->{'action'} eq 'user-sensitive') {
			$actions{$table->{'table'}."_user_sensitive"} = "update";
			$actions{$table->{'table'}} = "remap-only";
		} elsif (exists $know_actions{$table->{'action'}}) {
			$actions{ $self->table_name_after_renamed($table->{'table'}) } = $table->{'action'};
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

	return exists $self->{'hardcoded_lookup'}{$table_6}{$column_6} || $self->{'conditional_lookup'}{$table_6}{$column_6};
}

sub get_hardcoded_lookup {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'hardcoded_lookup'}{$table_6}{$column_6};
}

sub get_conditional_lookup {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'conditional_lookup'}{$table_6}{$column_6};
}

sub is_constant_value_exists {
    my ($self, $table_6, $column_6) = @_;
	
	return exists $self->{'constant_value'}{$table_6}{$column_6};
}

sub get_constant_value {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'constant_value'}{$table_6}{$column_6};
}

sub is_nullable_ignored {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'ignore_nullable'}{$table_6}{$column_6};
}

sub is_column_type_ignored {
    my ($self, $table_6, $column_6) = @_;
	
	return $self->{'ignore_type_change'}{$table_6}{$column_6};
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

package Migration::Rule::ForeignKey;

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
	
	return "link to [".$self->{'table'}.".".$self->{'column'}."]";
}

sub as_json {
    my ($self) = @_;

    tie my %r, "Tie::IxHash", (
    	'action' => "foreign-key",
    	'lookup_table' => $self->{'table'},
    	'lookup_column' => $self->{'column'},
    );
	return \%r;
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
	
	return "copy value from [".$self->{'table'}.".".$self->{'column'}."]";
}

sub as_json {
    my ($self) = @_;

    tie my %r, "Tie::IxHash", (
    	'action' => "copy",
    	'from_table' => $self->{'table'},
    	'from_column' => $self->{'column'},
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
		'action' => "autoincrement",
	};
}

package Migration::Rule::HardCodedLookup;

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
	
	return "hard-coded lookup from [".$self->{'map'}."] map";
}

sub as_json {
    my ($self) = @_;

    tie my %r, "Tie::IxHash", (
    	'action' => "hard-coded-lookup",
    	'map' => $self->{'map'},
    );
	return \%r;
}

package Migration::Rule::ConditionalLookup;

use base qw(Migration::Rule::HardCodedLookup);

sub as_string {
    my ($self) = @_;
	
	return "conditional lookup from [".$self->{'map'}."] map";
}

sub as_json {
    my ($self) = @_;

    tie my %r, "Tie::IxHash", (
    	'action' => "conditional-lookup",
    	'map' => $self->{'map'},
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

1;
