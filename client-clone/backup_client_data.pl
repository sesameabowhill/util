#!/usr/bin/perl
## $Header: //depot/Sesame/Server Projects/Common/Src/uninstall.pl#13 $
## $Id: backup_client_data.pl 2024 2010-05-06 18:06:41Z ivan $

use strict;

use DBI;
use File::Spec;
use File::Temp qw( tempdir );
use IO::File;
use Getopt::Long;
use Log::Log4perl;
use Cwd;

Log::Log4perl::init(
	{
		'log4perl.rootLogger'       => 'DEBUG, Screen, LogFile',
		'log4perl.appender.Screen'  => 'Log::Log4perl::Appender::Screen',
		'log4perl.appender.Screen.layout' => 'Log::Log4perl::Layout::PatternLayout',
		'log4perl.appender.Screen.layout.ConversionPattern' => '%d %F{1}> %p %m %n',
		'log4perl.appender.Screen.Threshold' => 'INFO',

		'log4perl.appender.LogFile' => 'Log::Log4perl::Appender::File',
		'log4perl.appender.LogFile.filename' => 'backup_client_data.log',
		'log4perl.appender.LogFile.mode' => 'append',
		'log4perl.appender.LogFile.layout' => 'Log::Log4perl::Layout::PatternLayout',
		'log4perl.appender.LogFile.layout.ConversionPattern' => '%d %F{1}> %p %m %n',
	}
);

my  %options = (
	'output_file' => undef,
	'only_table' => undef,
	'skip_table' => undef,
	'backup_db' => 1,
	'backup_folders' => 1,
	'db_max_query_length' => 50_000,
	'db_connection_string' => undef,
	'no_obfuscation' => undef,

	'cl_id' => undef,
	'cl_db' => undef,
	'cl_type' => undef,
	'cl_username' => undef,
	'cl_hhf_guid' => undef,
	'cl_web_folder' => undef,
);

GetOptions(
	'client-id=i'   => \$options{'cl_id'},
	'client-db=s'   => \$options{'cl_db'},
	'client-type=s' => \$options{'cl_type'},
	'output-file=s' => \$options{'output_file'},
	'only-table=s@' => \$options{'only_table'},
	'skip-table=s@' => \$options{'skip_table'},
	'no-obfuscation' => \$options{'no_obfuscation'},
	'db-connection-string=s' => \$options{'db_connection_string'},
);

my  $logger = Log::Log4perl->get_logger('backup_client_data.pl');
$options{'cl_db'} = shift @ARGV;
if ($options{'cl_db'}) {
	my  ($revision) = ( '$Revision: 2024 $' =~ m/(\d+)/ );
	$logger->debug("client data backup script revision [$revision]");
	DataAccess->init_database_access( $options{'db_connection_string'} );

	my $client = DataAccess->new_client(
		{
			'id' => $options{'cl_id'},
			'db' => $options{'cl_db'},
			'type' => $options{'cl_type'},
		}
	);

	$logger->debug("client: ".$client->as_string());

	if (defined $options{'only_table'}) {
		$logger->info("return only [".join(', ', @{ $options{'only_table'} })."] tables");
		$options{'backup_db'} = 0;
		$options{'backup_folders'} = 0;
	}

	my $data_filter = ($options{'no_obfuscation'} ?
		Obfuscation::Base->new(DataAccess->get_main_db_name()) :
		Obfuscation::Filter->new(DataAccess->get_main_db_name())
	);
	{

		my $linked_tables = $client->get_linked_tables();
		if (defined $options{'only_table'}) {
			my %filter = map {$_ => 1} @{ $options{'only_table'} };
			@$linked_tables = grep {exists $filter{ $_->{'table'} }} @$linked_tables;
		}
		my %skip_table;
		if (defined $options{'skip_table'}) {
			%skip_table = map {
				if ($_ !~ m/\./) {
					$_ = DataAccess->get_main_db_name().'.'.$_;
				}
				( $_ => 1 )
			} @{ $options{'skip_table'} };
			$logger->info("skip [".join(', ', sort keys %skip_table)."] tables");
		}
		my @existing_tables;
		for my $table (@$linked_tables) {
			if (DataAccess->check_table_exists( $table->{'table'} )) {
				if (exists $skip_table{ $table->{'table'} }) {
					$logger->info("table [".$table->{'table'}."] is skipped");
				}
				else {
					push(@existing_tables, $table);
				}
			}
			else {
				$logger->warn("table [".$table->{'table'}."] not found");
			}
		}

		$logger->info("going to check [".scalar(@existing_tables)."] tables or more");

		for my $t (@existing_tables) {
			my  $dbi = DataAccess->get_dbi();

			my @where_cond =
				map {$t->{key}{$_}.'='.$dbi->quote($client->$_())}
				grep {defined $client->$_()} keys %{ $t->{key} };

			if (@where_cond) {
				if (exists $t->{where}) {
					$logger->debug("add custom where conditions");
					push @where_cond, map {$_.'='.$dbi->quote($t->{where}{$_})} keys %{ $t->{where} };
				}

				my  $where = join ' AND ', @where_cond;

				$logger->debug("table [$t->{table}] where [$where]");

				{
					my  $count = $dbi->selectrow_array("SELECT COUNT(*) FROM $t->{table} WHERE $where");
					$logger->debug($count." record".($count==1?'':'s')." found in [$t->{table}]");
					if ($count > 0) {
						$logger->info("save: ".(exists $t->{'title'} ? $t->{'title'} : $t->{'table'}));
						do_table_clear($t->{'table'}, $where, $data_filter);
					}
				}

				if (exists $t->{'join'}) {
					save_join_table(
						$dbi,
						$t->{'join'},
						$t->{'table'},
						$where,
						1,
						\%skip_table,
						$data_filter
					);
				}
			}
			else {
				$logger->error("no keys found for: ".$t->{table});
			}
		}
	}

	if ($options{'backup_db'} && defined $client->get_database_name()) {
		$logger->info("save database: ".$client->get_database_name());
		do_db_clear($client->get_database_name());
	}
	else {
		$logger->warn("skip database backup");
	}

	if ($options{'backup_folders'}) {
		my $backup_folders = $client->get_backup_folders();
		$logger->error("no folders to copy") unless @$backup_folders;
		for my $f (@$backup_folders) {
			$logger->info("copy $f->{title} folder: ".$f->{folder});
			do_folder_clear($f->{folder}, $f->{title});
		}
	}
	else {
		$logger->warn("skip folder backup");
	}

	{
		archive_folder($client, $options{'output_file'});
	}
	my $seed = $data_filter->get_seed();
	if (defined $seed) {
		$logger->info("data seed [$seed]");
	}
}
else {
	print <<USAGE;
Usage: $0 [PARAMETERS] <client_db_name></client_db_name>
Parameters:
	--client-db - clients database name
	--client-id - clients id
	--client-type=<ortho|dental> - type of client
	--output-file - backup data will be put into this file
	--only-table - save only specific tables
	--skip-table - skip specific tables
	--no-obfuscation
USAGE
	exit(1);
}

sub save_join_table {
	my  ($dbi, $join_data, $table_name, $where, $level, $skip_table, $data_filter) = @_;

	my @existing_table_names;
	for my $join_tn (keys %$join_data) {
		if (DataAccess->check_table_exists($join_tn)) {
			if (exists $skip_table->{$join_tn}) {
				$logger->info("[$level]: join table [".$join_tn."] is skipped");
			}
			else {
				push(@existing_table_names, $join_tn);
			}
		}
		else {
			$logger->warn("[$level]: join table [$join_tn] not found");
		}
	}
	for my $join_tn (sort @existing_table_names) {
		my $join_params = $join_data->{$join_tn};

		my  @table_cond;
		my  %column_cond;
		my  $qr = $dbi->prepare("SELECT ".(join ', ', values %{ $join_params->{columns} })." FROM $table_name WHERE $where");
		$qr->execute();
		while (my $r = $qr->fetchrow_hashref()) {
			my  @cond;
			while (my ($join_col, $prim_col) = each %{ $join_params->{columns} }) {
				push @cond, $join_col.'='.$dbi->quote($r->{$prim_col});
				push @{ $column_cond{$join_col} }, $dbi->quote($r->{$prim_col});
			}
			push @table_cond, '('.(join ' AND ', @cond).')';
		}
		if (@table_cond) {
			my @join_where = ( join(' OR ', @table_cond) );
			if ( keys(%column_cond) == 1 ) {
				my  ($k) = keys %column_cond;
				@join_where = ();
				my @current_join_where;
				my $current_join_where_length = 0;
				for my $cond (@{ $column_cond{$k} }) {
					push( @current_join_where, $cond );
					$current_join_where_length += 2 + length($cond);
					if ($current_join_where_length > $options{'db_max_query_length'}) {
						push(
							@join_where,
							$k." IN (".join(', ', @current_join_where).")",
						);
						@current_join_where = ();
						$current_join_where_length = 0;
					}
				}
				if (@current_join_where) {
					push(
						@join_where,
						$k." IN (".join(', ', @current_join_where).")",
					);
				}
			}
			my $where_index = 1;
			for my $join_where (@join_where) {
				my $count = $dbi->selectrow_array("SELECT COUNT(*) FROM $join_tn WHERE $join_where");
				if ($count > 0) {
					$logger->info("[$level]: save joined table: $join_tn" . (@join_where>1?' '.$where_index.'/'.@join_where:''));
					do_table_clear($join_tn, $join_where, $data_filter);
					if (exists $join_params->{'join'}) {
						save_join_table(
							$dbi,
							$join_params->{'join'},
							$join_tn,
							$join_where,
							$level+1,
							$skip_table,
							$data_filter,
						);
					}
				}
				$where_index++;
			}
		}
		else {
			$logger->debug("[$level]: no join records to save in [$join_tn]");
		}
	}
}



{
	my  $back_up_folder = undef;
	my  $back_up_db_file = undef;

	sub _init_back_up_folder {
		unless ($back_up_folder) {
			$back_up_folder = tempdir( 'CLEANUP' => 1 );
			$logger->debug("backup folder [$back_up_folder]");
		}
	}

	my  @shell_commands;
	my  @sql_commands;

	sub do_table_clear {
		my  ($table, $where, $data_filter) = @_;

		my  $dbi = DataAccess->get_dbi();
		_init_back_up_folder();
		unless ($back_up_db_file) {
			$back_up_db_file = IO::File->new();
			$back_up_db_file->open(File::Spec->catfile($back_up_folder, "databases.sql"), ">")
				or $logger->logdie("can't create file in [$back_up_folder]: $!");
			my  ($revision) = ( '$Revision: 2024 $' =~ m/(\d+)/ );
			$back_up_db_file->print("-- this file is created by client data backup script (revision $revision)\n\n");
		}
		my  $qr = $dbi->prepare("SELECT * FROM $table WHERE $where");
		$qr->execute();
		$back_up_db_file->print("-- table $table\n");
		$back_up_db_file->print("START TRANSACTION;\n");
		my $table_backup_output = TableBackupOutput->new(
			$back_up_db_file,
			$table,
			$qr->{'NAME'},
		);
		while (my $r = $qr->fetchrow_hashref()) {
			$r = $data_filter->filter_row($table, $r);
			if (defined $r) {
				$table_backup_output->add_data($r);
			}
#			my  $sql = "INSERT INTO $table (".join(', ', map {"`$_`"} keys %$r).") VALUES (".join(', ', map {$dbi->quote($_)} values %$r).");";
#			$back_up_db_file->print("$sql\n");
		}
		$table_backup_output->flush();
		$back_up_db_file->print("COMMIT;\n");
		$back_up_db_file->print("\n");
	}

	sub do_db_clear {
		my  ($db_name) = @_;

		_init_back_up_folder();
		my $cmd = 'mysqldump '.DataAccess->get_mysql_cmd_options().' '.$db_name;
		$cmd .= ' > "'.File::Spec->catfile($back_up_folder, "client_db_$db_name.sql").'"';

		$logger->debug("CMD: $cmd");
		system($cmd);
	}

	sub do_folder_clear {
		my  ($folder, $name) = @_;

		unless (-d $folder) {
			$logger->error("folder [$folder] doesn't exists");
			return;
		}

		_init_back_up_folder();
		my  $dir = File::Spec->catfile($back_up_folder, $name);
		mkdir($dir) or $logger->logdie("can't create folder [$dir]: $!");
		my  $cmd = qq(cp -r "$folder" "$dir");
		$logger->debug("CMD: $cmd");
		system($cmd);
	}

	sub archive_folder {
		my ($client, $archive_name) = @_;
		_init_back_up_folder();

		unless (defined $archive_name) {
			$archive_name = defined $client->db() ?
				'_client_data_backup_'.$client->db() :
				'_client_data_backup_'.$client->id()."_".$client->type();

			my  @tt = (localtime())[0..5];
			$tt[5] += 1900;
			$tt[4] ++;
			$archive_name .= sprintf('_%04d%02d%02d%02d%02d%02d.tar.gz', reverse(@tt));
		}

		$logger->info("make archive [$archive_name]");

		#my  $cmd = qq(cd "$back_up_folder"; tar czf "$archive_name" *);
		$archive_name = File::Spec->join(getcwd(), $archive_name);
		my $cmd = qq(cd "$back_up_folder"; tar czf "$archive_name" *);
		$logger->debug("CMD: $cmd");
		system($cmd);
	}

}


package DataAccess;

sub check_table_exists {
	my  ($class, $db_name, $table_name) = @_;

	if (@_ == 2) {
		($db_name, $table_name) = split /\./, $db_name, 2;
	}

	return 0 unless $class->check_db_exists($db_name);

	my  $dbi = get_dbi();
	return length $dbi->selectrow_array("SHOW TABLES FROM `".$db_name."` LIKE ".$dbi->quote($table_name));
}

sub check_db_exists {
	my  ($class, $db_name) = @_;

	my  $dbi = get_dbi();
	return length $dbi->selectrow_array("SHOW DATABASES LIKE ".$dbi->quote($db_name));
}

sub read_config_file {
	my ($class, $file_name) = @_;

	open(my $f, "<", $file_name) or die "can't read [$file_name]: $!";
	local $/;
	my $data = <$f>;
	close($f);
	{
		no strict;
		return eval "$data";
	}
}

{
	my $db_options;
	my $dbi;

	sub init_database_access {
		my ($class, $db_connection_string) = @_;

		$ENV{'SESAME_ROOT'} //= '/home/sites';
		$logger->info("current sesame version is [5]");
		my $core_config_file = File::Spec->join($ENV{'SESAME_ROOT'}, 'sesame', 'config', 'sesame_core.conf');
		$logger->info("read config [$core_config_file]");
		my $core_config = $class->read_config_file($core_config_file);
		$db_options = {
			'db_host'     => $core_config->{'database_access'}{'server_address'},
			'db_port'     => $core_config->{'database_access'}{'server_port'},
			'db_user'     => $core_config->{'database_access'}{'user'},
			'db_password' => $core_config->{'database_access'}{'password'},
			'db_name'     => $core_config->{'database_access'}{'database_name'},
		};
		if (defined $db_connection_string) {
			## admin:higer4@127.0.0.1:3306/sesame_db
			if ($db_connection_string =~ m{^(\w+):(\w+)\@([\w.-]+)(?::(\d+))?(?:/(\w+))?$}) {
				$db_options = {
					'db_user'     => $1,
					'db_password' => $2,
					'db_host'     => $3,
					'db_port'     => ($4 || 3306),
					'db_name'     => $5,
				};
				$logger->info("override DB connection parameters by [$db_connection_string]");
				if (! defined $db_options->{'db_name'}) {
					die "database name is not specified in [$db_connection_string] to work for [5]";
				}
			}
			else {
				die "invalid connection string [$db_connection_string]";
			}

		}
	}

	sub new_client {
		my ($class, $params) = @_;

		return Client::Sesame_5->new($params);
	}

	sub get_mysql_cmd_options {
		my ($class) = @_;

		unless ($db_options) {
			die "database options are not set";
		}

		return qq("-h$db_options->{db_host}" "-u$db_options->{db_user}" "-p$db_options->{db_password}" "-P$db_options->{db_port}");
	}

	sub get_main_db_name {
		my ($class) = @_;

		unless ($db_options) {
			die "database options are not set";
		}
		return $db_options->{'db_name'};
	}

	sub get_dbi {
		my ($class) = @_;

		unless ($db_options) {
			die "database options are not set";
		}
		unless ($dbi) {
			$logger->info("connecting to DB server [".$db_options->{'db_host'}."] as [".$db_options->{'db_user'}."]");
			$dbi = DBI->connect(
				'DBI:mysql:' .
					'host=' . $db_options->{'db_host'} .
					';port=' . $db_options->{'db_port'} .
					($db_options->{'db_name'} ? ';database=' . $db_options->{'db_name'} :''),
				$db_options->{'db_user'},
				$db_options->{'db_password'},
				{
					'RaiseError' => 1,
					'ShowErrorStatement' => 1,
					'PrintError' => 0,
				}
			);
		}
		return $dbi;
	}
}

package TableBackupOutput;

sub new {
	my ($class, $file, $table_name, $columns) = @_;

	return bless {
		'file' => $file,
		'table_name' => $table_name,
		'columns' => $columns,
		'current_query' => undef,
		'max_query_length' => $options{'db_max_query_length'},
	}, $class;
}

sub add_data {
	my ($self, $data) = @_;

	if (defined $self->{'current_query'}) {
		$self->{'current_query'} .= ', ';
	}
	else {
		$self->{'current_query'} = sprintf(
			'INSERT INTO %s (%s) VALUES',
			_quote_table_name( $self->{'table_name'} ),
			join(', ', map {"`$_`"} @{ $self->{'columns'} }),
		);
	}
	$self->{'current_query'} .= '('.join(', ', map {_quote($_)} @$data{ @{ $self->{'columns'} } } ).')';
	if (length $self->{'current_query'} > $self->{'max_query_length'}) {
		$self->flush();
	}
}

sub flush {
	my ($self) = @_;

	if (defined $self->{'current_query'}) {
		$self->{'file'}->print($self->{'current_query'}, ";\n");
		$self->{'current_query'} = undef;
	}
}

sub _quote {
	my ($str) = $_;

	my $dbi = DataAccess->get_dbi();
	return $dbi->quote($str);
}

sub _quote_table_name {
	my ($table_name) = @_;

	my @parts = split(m/\./, $table_name, 2);
	if (@parts > 1) {
		shift(@parts); ## remove database name
	}
	return join('.', map {"`$_`"} @parts);
}

sub DESTROY {
	my ($self) = @_;

	$self->flush();
}

package Client;

sub new {
	my  ($class, $params) = @_;

	my  $self = bless {
			'id' => undef,
			'db' => undef,
			'type' => undef,
			%$params,
			'_logger' => Log::Log4perl->get_logger(__PACKAGE__),
		}, $class;

	return $self;
}

sub as_string {
	my  ($self) = @_;

	return join ' ', map {"$_ [$self->{$_}]"} grep {$_ !~ /^_/ && defined $self->{$_}} keys %$self;
}

package Client::Sesame_5;

use base 'Client';

sub db {
	my ($self) = @_;

	unless ($self->{'db'}) {
		if (defined $self->{'id'}) {
			my $dbi = DataAccess->get_dbi();
			$self->{'db'} = $dbi->selectrow_array(
				"SELECT cl_username FROM client WHERE id=?",
				undef,
				$self->{'id'},
			);
		}
		else {
			$self->{'_logger'}->logdie("can't get username without id");
		}
	}
	return $self->{'db'};
}

sub id {
	my ($self) = @_;

	unless ($self->{'id'}) {
		if (defined $self->{'db'}) {
			my $dbi = DataAccess->get_dbi();
			$self->{'id'} = $dbi->selectrow_array(
				"SELECT id FROM client WHERE cl_username=?",
				undef,
				$self->{'db'},
			);
		}
		else {
			$self->{'_logger'}->logdie("can't get id without username");
		}
	}
	return $self->{'id'};
}


sub get_linked_tables {
	my ($self) = @_;

	my $client_dependences_file = File::Spec->join($ENV{'SESAME_ROOT'}, 'sesame', 'utils', 'client_dependences.pl');
	my $client_dependences = DataAccess->read_config_file($client_dependences_file);

	my $main_db = DataAccess->get_main_db_name();
	my @tables;
	my %unique_tables;
	for my $table_name (keys %$client_dependences) {
		$unique_tables{$table_name} ++;
		my $value = $client_dependences->{$table_name};
		$value->{'table'} = $main_db.'.'.$table_name;
		$value->{'key'} = {'id' => 'id'};
		if (exists $value->{'join'}) {
			$value->{'join'} = _add_database_name($main_db, $value->{'join'}, \%unique_tables);
		}
		push(@tables, $value);
	}
	return \@tables;
}

sub _add_database_name {
	my ($database, $join_nodes, $unique_tables) = @_;

	my %nodes;
	my @unique_tables_this_level = grep { ! $unique_tables->{$_}++ } keys %$join_nodes;
	for my $table (@unique_tables_this_level) {
		my $param = $join_nodes->{$table};
		if (defined $param->{'join'}) {
			$param->{'join'} = _add_database_name($database, $param->{'join'}, $unique_tables);
			unless (keys %{ $param->{'join'} }) {
				$param->{'join'} = undef;
			}
		}
		$nodes{$database.'.'.$table} = $param;
	}
	return \%nodes;
}

sub get_backup_folders {
	my ($self) = @_;

	return [];
}

sub get_database_name {
	my ($self) = @_;

	return undef;
}


package Obfuscation::Base;

sub new {
	my ($class) = @_;

	return bless {
	}, $class;
}

sub filter_row {
	my ($self, $table, $row) = @_;

	return $row;
}

sub get_seed {}

package Obfuscation::Filter;

## base on http://wiki.sesamecommunications.com:8090/display/PD/Production+data+obfuscation

use Digest::MD5 'md5_base64', 'md5_hex';
use Sys::Hostname;

use base 'Obfuscation::Base';

sub new {
	my ($class, $db_name) = @_;

	my %update_columns;
	## obfuscate
#	$update_columns{$db_name.'.'.'address_local'}{'street'} = undef;
#	$update_columns{$db_name.'.'.'address_local'}{'city'} = undef;
#	$update_columns{$db_name.'.'.'address_versioned'}{'street'} = undef;
#	$update_columns{$db_name.'.'.'address_versioned'}{'city'} = undef;
#	$update_columns{$db_name.'.'.'address_versioned'}{'pms_id'} = undef;
	$update_columns{$db_name.'.'.'client_access'}{'user_passwd'} = undef;
	$update_columns{$db_name.'.'.'client_access'}{'user_enc_passwd'} = undef;
#	$update_columns{$db_name.'.'.'email_local'}{'email'} = undef;
#	$update_columns{$db_name.'.'.'email_local'}{'relative_name'} = undef;
#	$update_columns{$db_name.'.'.'email_sent_mail_log'}{'sml_email'} = undef;
#	$update_columns{$db_name.'.'.'email_sent_mail_log'}{'sml_name'} = undef;
#	$update_columns{$db_name.'.'.'email_unsubscribe'}{'email'} = undef;
#	$update_columns{$db_name.'.'.'email_versioned'}{'email'} = undef;
#	$update_columns{$db_name.'.'.'email_versioned'}{'relative_name'} = undef;
#	$update_columns{$db_name.'.'.'email_versioned'}{'pms_id'} = undef;
#	$update_columns{$db_name.'.'.'hhf_applications'}{'fname'} = undef;
#	$update_columns{$db_name.'.'.'hhf_applications'}{'lname'} = undef;
	$update_columns{$db_name.'.'.'invisalign_case_process_doctor'}{'password'} = undef;
	$update_columns{$db_name.'.'.'invisalign_case_process_doctor'}{'adf_password'} = undef;
#	$update_columns{$db_name.'.'.'invisalign_case_process_patient'}{'fname'} = undef;
#	$update_columns{$db_name.'.'.'invisalign_case_process_patient'}{'lname'} = undef;
#	$update_columns{$db_name.'.'.'invisalign_case_process_patient'}{'adf_file'} = undef;
#	$update_columns{$db_name.'.'.'invisalign_patient'}{'fname'} = undef;
#	$update_columns{$db_name.'.'.'invisalign_patient'}{'lname'} = undef;
#	$update_columns{$db_name.'.'.'opse_payment_log'}{'FName'} = undef;
#	$update_columns{$db_name.'.'.'opse_payment_log'}{'LName'} = undef;
#	$update_columns{$db_name.'.'.'opse_payment_log'}{'EMail'} = undef;
#	$update_columns{$db_name.'.'.'opse_payment_log'}{'Comment'} = undef;
#	$update_columns{$db_name.'.'.'phone_local'}{'number'} = undef;
#	$update_columns{$db_name.'.'.'phone_versioned'}{'number'} = undef;
#	$update_columns{$db_name.'.'.'phone_versioned'}{'pms_id'} = undef;
#	$update_columns{$db_name.'.'.'referrer_local'}{'email'} = undef;
#	$update_columns{$db_name.'.'.'referrer_versioned'}{'email'} = undef;
	$update_columns{$db_name.'.'.'si_doctor'}{'Password'} = undef;
#	$update_columns{$db_name.'.'.'si_patient'}{'FName'} = undef;
#	$update_columns{$db_name.'.'.'si_patient'}{'LName'} = undef;
#	$update_columns{$db_name.'.'.'sms_message_history'}{'phone'} = undef;
	$update_columns{$db_name.'.'.'visitor_user_sensitive'}{'password'} = undef;
#	$update_columns{$db_name.'.'.'visitor_versioned'}{'first_name'} = undef;
#	$update_columns{$db_name.'.'.'visitor_versioned'}{'last_name'} = undef;
#	$update_columns{$db_name.'.'.'visitor_versioned'}{'pms_id'} = undef;
#	$update_columns{$db_name.'.'.'email_referral'}{'ref_lname'} = undef;
#	$update_columns{$db_name.'.'.'email_referral'}{'ref_fname'} = undef;
#	$update_columns{$db_name.'.'.'email_referral'}{'ref_email'} = undef;
#	$update_columns{$db_name.'.'.'email_referral_mail'}{'from_email'} = undef;
#	$update_columns{$db_name.'.'.'voice_reminder_settings'}{'transfer_phone'} = undef;
	## override
#	$update_columns{$db_name.'.'.'email_reminder_settings'}{'is_enabled'} = '0';
	$update_columns{$db_name.'.'.'email_sending_queue'}{'sent_date'} = '2010-09-08 07:06:05';
#	$update_columns{$db_name.'.'.'hhf_applications'}{'body'} = '<Groups/>';
	$update_columns{$db_name.'.'.'holiday_settings'}{'hds_status'} = '0';
	$update_columns{$db_name.'.'.'ppn_email_queue'}{'is_send'} = '1';
#	$update_columns{$db_name.'.'.'voice_reminder_settings'}{'is_enabled'} = '0';
	
	$update_columns{$db_name.'.'.'client'}{'cl_status'} = '0';
	$update_columns{$db_name.'.'.'client'}{'pms_software_id'} = '24';
	$update_columns{$db_name.'.'.'client'}{'pms_version'} = '';
#	$update_columns{$db_name.'.'.'client_access'}{'user_password'} = '1';

	my $data_seed = md5_base64(rand().time().hostname().'0scEru960WO8CiBcS82k');
	return bless {
		'seed' => $data_seed,
		'password_seed' => md5_base64(rand().$data_seed),
		'clear_table' => {
			$db_name.'.'.'sms_queue' => 1,
			$db_name.'.'.'token' => 1,
			$db_name.'.'.'voice_queue' => 1,
			$db_name.'.'.'voice_queue' => 1,
		},
		'settings_table' => {
			$db_name.'.'.'client_setting' => {
				'PKey' => {
					'Reminder.PostApp->SurveyEmails' => 1,
					'Client.Email->Optional' => 1,
					'Client.Email->From' => 1,
					'Voice.CallerId' => 1,
					'Voice.RL.DoctorPhone' => 1,
				},
			},
			$db_name.'.'.'hhf_settings' => {
				'PKey' => {
					'email' => 1,
				},
			},
		},
		'update_column' => \%update_columns,
	}, $class;
}

sub filter_row {
	my ($self, $table, $row) = @_;

	if (exists $self->{'clear_table'}{$table}) {
		return undef;
	}
	elsif (exists $self->{'settings_table'}{$table}) {
		my $where_columns = $self->{'settings_table'}{$table};
		my $hide_data = 0;
		for my $where_column (keys %$where_columns) {
			for my $where_value (keys %{ $where_columns->{$where_column} }) {
				if (lc $row->{$where_column} eq lc $where_value) {
					$hide_data = 1;
				}
			}
		}
		if ($hide_data) {
			while (my ($column, $value) = each %$row) {
				if (exists $where_columns->{$column}) {
					## ignore if is number or used in where
				}
				else {
					$row->{$column} = $self->_hide_number_value($column, $value);
				}
			}
		}
	}
	elsif (exists $self->{'update_column'}{$table}) {
		my $override = $self->{'update_column'}{$table};
		while (my ($column, $override_value) = each %$override) {
			if (exists $row->{$column}) {
				
				if (defined $override_value) {
					$row->{$column} = $override_value;
				}
				else {
					$row->{$column} = $self->_hide_value($column, $row->{$column});
				}
			}
		}
	}
	elsif (table_has_email($table))  {
		while (my ($column, $value) = each %$row) {
			$row->{$column} = make_email_invalid($column, $value);
		}
	} elsif (table_has_phone($table)) {
		while (my ($column, $value) = each %$row) {
			$row->{$column} = make_phone_invalid($column, $value);
		}
	}
	else {		 
		## do nothing for all other tables
	}
	return $row;
}

sub make_phone_invalid  {
	my ($column, $value) = @_;
	my $area_code;
	my $klondike_5 = 555;
	my $end;

	if ($column eq 'number' || $column eq 'transfer_phone' || $column eq 'rec_phone' || $column eq 'phone' || $column eq 'value') {
		if ($column eq 'value') {
			# a special case for 'client_properties' because its column 'values' has phone numbers and other attributes
			my $value_copy = $value;
			$value_copy =~ s/[^0-9]*//g;
				if (length $value_copy < 6) {
					# it is not a number so don't modify it
					return $value;
				}
		}
		my $phone_length = length $value;
		if ($phone_length == 7) {
			$end = substr $value , 3, 4;
			return $klondike_5.$end;
		} elsif ($phone_length == 10) {
			$area_code = substr $value, 0, 3;
			$end = substr $value , 6, 4;
			return $area_code.$klondike_5.$end;
		} elsif ($phone_length == 11) {
			$area_code = substr $value, 0, 4;
			$end = substr $value , 7, 4;
			return $area_code.$klondike_5.$end;
		} elsif ($phone_length == 12) {
			$area_code = substr $value, 0, 4;
			$end = substr $value , 8, 4;
			return $area_code.$klondike_5.$end;
		}
	} elsif ($column eq 'is_valid') {
		my $int_value = unpack('c', $value);
		return $int_value;
	}
	#It is not a phone number so don't modify
	return $value;
}

sub make_email_invalid  {
	my ($column, $value) = @_;
	
	if ($column eq 'email' || $column eq 'ref_email' || $column eq 'from_email' || $column eq 'email_from' || $column eq 'email_to' || $column eq 'sml_email' || $column eq 'sfl_emailto' || $column eq 'EMail') {
		if (index($value, '.email') == -1) {
			$value =  $value.'.email';
			return $value;
		} else {
			return $value;
		}
	} elsif ($column eq 'is_valid') {
		my $int_value = unpack('c', $value);
		return $int_value;
	}
	#It is not an email address so don't modify
	return $value;
}

sub table_has_email {
	my ($table) = @_;
	
	if (	index($table, 'email_local') != -1 || 
			index($table, 'email_versioned') != -1 || 
			index($table, 'email_unsubscribe') != -1 || 
			index($table, 'email_sent_mail_log') != -1 || 
			index($table, 'email_referral') != -1 || 
			index($table, 'email_sent_mail_log') != -1 || 
			index($table, 'hhf_log') != -1 || 
			index($table, 'invisalign_send2friend') != -1 || 
			index($table, 'orphan_email') != -1 || 
			index($table, 'opse_payment_log') != -1 || 
			index($table, 'send2friend_log') != -1 || 
			index($table, 'si_doctor') != -1
		) {
			#return true
			return 1;
		}
		#return false
		return 0;
}
sub table_has_phone {
	my ($table) = @_;
	
	if (	index($table, 'phone_local') != -1 || 
			index($table, 'phone_versioned') != -1 || 
			index($table, 'voice_reminder_settings') != -1 || 
			index($table, 'voice_no_call_list') != -1 || 
			index($table, 'printable_ledger') != -1 || 
			index($table, 'review_business_info') != -1 || 
			index($table, 'sms_queue') != -1 || 
			index($table, 'sms_message_history') != -1 || 
			index($table, 'voice_message_history') != -1 || 
			index($table, 'voice_queue') != -1 || 
			index($table, 'voice_system_transaction_log') != -1 || 
			index($table, 'client_properties') != -1
		) {
		#return true
		return 1;		
	}
	#return false
	return 0;
}

sub _hide_number_value {
	my ($self, $column, $value) = @_;

	if (defined $value && $value =~ m{^\d+(?:\.\d+)?$}) { ## in fact we're skiping ids here
		return $value;
	}
	else {
		return $self->_hide_value($column, $value);
	}
}

sub _hide_value {
	my ($self, $column, $value) = @_;

	return (defined $value && length $value ?
		md5_hex(
			$value .
			($column =~ m{password|passwd}i ?
				$self->{'password_seed'} :
				$self->{'seed'}
			)
		) :
		$value
	);
}

sub get_seed {
	my ($self) = @_;

	return $self->{'seed'};
}


