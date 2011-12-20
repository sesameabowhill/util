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
						do_table_clear($t->{table}, $where);
					}
				}

				if (exists $t->{join}) {
					save_join_table($dbi, $t->{join}, $t->{table}, $where, 1, \%skip_table);
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
}
else {
	print <<USAGE;
Usage: $0 [PARAMETERS] <client_db_name>
Parameters:
	--client-db - clients database name
	--client-id - clients id
	--client-type=<ortho|dental> - type of client
	--output-file - backup data will be put into this file
	--only-table - save only specific tables
	--skip-table - skip specific tables
USAGE
	exit(1);
}

sub save_join_table {
	my  ($dbi, $join_data, $table_name, $where, $level, $skip_table) = @_;

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
					do_table_clear($join_tn, $join_where);
					if (exists $join_params->{join}) {
						save_join_table($dbi, $join_params->{join}, $join_tn, $join_where, $level+1, $skip_table);
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
		my  ($table, $where) = @_;

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
			$table_backup_output->add_data($r);
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
