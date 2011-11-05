#!/usr/bin/perl
## $Header: //depot/Sesame/Server Projects/Common/Src/uninstall.pl#13 $

use strict;

use DBI;
use File::Spec;
use IO::File;
use Getopt::Long;
use Log::Log4perl;

Log::Log4perl::init({
        'log4perl.rootLogger'       => 'DEBUG, Screen, LogFile',
        'log4perl.appender.Screen'  => 'Log::Log4perl::Appender::Screen',
        'log4perl.appender.Screen.layout' => 'Log::Log4perl::Layout::PatternLayout',
        'log4perl.appender.Screen.layout.ConversionPattern' => '%d %F{1}> %p %m %n',
        'log4perl.appender.Screen.Threshold' => 'INFO',

        'log4perl.appender.LogFile' => 'Log::Log4perl::Appender::File',
        'log4perl.appender.LogFile.filename' => 'uninstall.log',
        'log4perl.appender.LogFile.mode' => 'append',
        'log4perl.appender.LogFile.layout' => 'Log::Log4perl::Layout::PatternLayout',
        'log4perl.appender.LogFile.layout.ConversionPattern' => '%d %F{1}> %p %m %n',
    });

my  %options = (
        'drop_db' => 1,
        'delete_folder' => 1,
        'backup_db' => 1,
        'backup_folders' => 1,
        'db_host' => $ENV{SESAME_DB_SERVER},
        'db_user' => 'admin',
        'db_password' => 'higer4',
        'do_remove' => 1,

        'cl_id' => undef,
        'cl_db' => undef,
        'cl_type' => undef,
        'cl_username' => undef,
        'cl_hhf_guid' => undef,
        'cl_web_folder' => undef,
    );
my  %params = (
        'ortho' => {
            'main_db_name' => 'sesameweb',
            'ppn_db_name' => 'newsletters_ortho',
            'common_log_type' => 'Ortho',
            'si_type' => 'Ortho',
            'opse_type' => 'Ortho',
            'profile_table' => 'properties',
            'voice_type' => 'ortho',
            'survey_type' => 'Ortho',
			'switchers_type' => 'Ortho',
        },
        'dental' => {
            'main_db_name' => 'dentists',
            'ppn_db_name' => 'newsletters_dental',
            'common_log_type' => 'Dental',
            'si_type' => 'Dental',
            'opse_type' => 'Dental',
            'profile_table' => 'profile',
            'voice_type' => 'dental',
            'survey_type' => 'Dental',
			'switchers_type' => 'Dental',
        },
    );

GetOptions(
        'drop-db!' => \$options{'drop_db'},
        'delete-folder!' => \$options{'delete_folder'},
        'client-id=i' => \$options{'cl_id'},
        'client-db=s' => \$options{'cl_db'},
        'client-type=s' => \$options{'cl_type'},
    );

$options{cl_db} = shift @ARGV;
if (!$options{cl_db}) {
    print <<USAGE;
Usage: $0 [PARAMETERS] <client_db_name>
Parameters:
    --drop-db       - drop client database (on by default)
    --delete-folder - delete client folder (on by default)

    --client-db - clients database name
    --client-id - clients id
    --client-type=<ortho|dental> - type of client
USAGE
    exit(1);
}

## folders:
## web
## site0: $ENV{SESAME_ROOT}/sites/site0/web/upload/data/$
## image upload
## SRM

my  $logger = Log::Log4perl->get_logger('uninstall.pl');
my  ($revision) = ( '$Revision: #13 $' =~ m/(\d+)/ );
$logger->debug("uninstall script revision [$revision]");

my  $client = Client->new({
        id => $options{cl_id},
        db => $options{cl_db},
        type => $options{cl_type},
    });

if ($client->type()) {
    if ($client->type() ne 'ortho' && $client->type() ne 'dental') {
        $logger->logdie("invalid client type [".$client->type()."]");
    }
} else {
    $logger->logdie("need client type");
}

$logger->debug("client: ".$client->as_string());

my  @remove_folders = ({
        title => 'web',
        folder => $client->web_folder(),
    }, {
        title => 'upload',
        folder => $client->upload_folder(),
    }, {
        title => 'si_images',
        folder => $client->image_folder(),
    }, {
        title => 'SRM',
        folder => $client->srm_folder(),
    });

## title, table, cl_id_key, cl_db_field, cl_type_field, type: single|many
my  $main_db_name = $params{$client->type()}{main_db_name};
my  @remove_subs = ({
        title => 'clients',
        table => $main_db_name.'.clients',
        key => { id => 'cl_id' },
    }, {
        title => 'clients_ext',
        table => $main_db_name.'.clients_ext',
        key => { id => 'cl_id' },
    }, {
        title => 'custom_mail_queue',
        table => $main_db_name.'.custom_mail_queue',
        key => { id => 'client_id' },
        type => 'many',
    }, {
        title => 'extractor_log: history',
        table => $main_db_name.'.extractor_log_history',
        key => { id => 'cl_id' },
        type => 'many',
    }, {
        title => 'extractor_log: version history',
        table => $main_db_name.'.extractor_log_version_history',
        key => { id => 'cl_id' },
        type => 'many',
    }, {
        title => 'holiday reminders: sent log',
        table => $main_db_name.'.holiday_delivery_log',
        key => { id => 'cl_id' },
        type => 'many',
        join => {
            $main_db_name.'.holiday_settings_recipients_link_log' => {
                columns => { 'hdl_id' =>  'hdl_id' }
            },
        },
    }, {
        title => 'holiday reminders: settings',
        table => $main_db_name.'.holiday_settings',
        key => { id => 'cl_id' },
        type => 'many',
        join => {
            $main_db_name.'.holiday_settings_recipients_link' =>  {
                columns => { 'hds_id' =>  'hds_id' },
            },
        },
    }, {
        title => 'htaccess',
        table => 'htaccess.user_info',
        key => { username => 'user_name' },
    }, {
        title => 'common_log',
        table => 'common_log.Clients',
        key => { id => 'outer_id' },
        where => { category => $params{$client->type()}{common_log_type} },
        join => {
            'common_log.Email_Address_Counts' => { columns => { id => 'id' } },
            'common_log.MOS' => { columns => { id => 'id' } },
            'common_log.Performance' => { columns => { id => 'id' } },
            'common_log.SMS_Log' => { columns => { client_id => 'id' } },
            'common_log.SPM_Events' => { columns => { id => 'id' } },
            'common_log.SPM_Ideas' => { columns => { cl_id => 'id' } },
            'common_log.SPM_Log' => { columns => { id => 'id' } },
        },
    }, {
        title => 'common_log: SMS statistics',
        table => 'common_log.SMS_Statistics',
        key => { id => 'sesame_user_id' },
        where => { sesame_type => $params{$client->type()}{common_log_type} },
    }, {
        title => 'PPN: queue',
        table => $params{$client->type()}{ppn_db_name}.'.email_queue',
        key => { id => 'cl_id' },
        join => {
            $params{$client->type()}{ppn_db_name}.'.article_queue' => {
                columns => { queue_id => 'id' },
            },
        },
    }, {
        title => 'HHF',
        table => 'hhf.clients',
        key => { hhf_guid => 'guid' },
        join => {
            'hhf.hhf_log' => { columns => { cl_id => 'id' } },
            'hhf.applications' => { columns => { cl_id => 'id' } },
            'hhf.settings' => { columns => { cl_id => 'id' } },
            'hhf.templates' => { columns => { cl_id => 'id' } },
        },
    }, {
        title => 'SI',
        table => 'si_upload.Clients',
        key => { id => 'outer_id' },
        where => { category => $params{$client->type()}{si_type} },
        join => {
            'si_upload.Monitoring' => { columns => { cl_id => 'id' } },
            'si_upload.Notes' => { columns => { cl_id => 'id' } },
            'si_upload.ClientTasks' => { columns => { cl_id => 'id' } },
        },
    }, {
        title => 'CC Payment (OPSE)',
        table => 'opse.clients',
        key => { id => 'OuterId' },
        where => { Category => $params{$client->type()}{opse_type} },
        join => {
            'opse.payment_log' => { columns => { CID => 'CID' } },
            #'opse.registry' => { 'PKey LIKE "Client.%s.%%"' => 'CID' },
        },
    }, {
        title => 'SRM: resource list',
        table => 'srm.resources',
        key => { db => 'container' },
        type => 'many',
    }, {
        title => 'Voice',
        table => 'voice.Clients',
        key => { db => 'db_name' },
        where => { category => $params{$client->type()}{voice_type} },
        join => {
            'voice.Queue'            => { columns => { cid => 'id' } },
            'voice.CBLinks'          => { columns => { cid => 'id' } },
            'voice.ClientSoundBites' => { columns => { cid => 'id' } },
            'voice.NoCallList'       => { columns => { cid => 'id' } },
            'voice.MessageHistory'   => {
                columns => { cid => 'id' },
                join => {
                    'voice.RecipientsList'    => { columns => { RLId => 'rec_id' } },
					'voice.XmlRequestHistory' => { columns => { message_history_id => 'id' } },
                },
            },
            'voice.PatientNamePronunciation' => { columns => { cid => 'id' } },
            'voice.SBRecordSessions'         => { columns => { cid => 'id' } },
            'voice.SystemTransactionLog'     => { columns => { cid => 'id' } },
            'voice.TransactionsLog'          => { columns => { cid => 'id' } },
            'voice.EmergencyCalls'           => {
                columns => { voice_client_id => 'id' },
                join => {
                    'voice.EmergencyCallTree' => { columns => { call_id => 'call_id' } },
                },
            },
            'voice.NotificationMessageHistory' => { columns => { voice_client_id => 'id' } },
            'voice.LeftMessages' => { columns => { cid => 'id' } },
			'voice.EndMessage' => { columns => { cid => 'id' } },
			'voice.autofills' => { columns => { cid => 'id' } },
			'voice.OfficeNamePronunciation' => { columns => { cid => 'id' } },
        },
    }, {
        title => 'SMS',
        table => 'sms.Clients',
        key => { sms_guid => 'Id' },
        join => {
            'sms.Queue' => { columns => { cid => 'id' } },
            'sms.MessageHistory' => { columns => { cid => 'id' } },
        },
    }, {
        title => 'Surveys',
        table => 'survey.clients',
        key => { id => 'OuterId' },
        where => { Category => $params{$client->type()}{survey_type} },
        join => {
            'survey.clients_forms' => { columns => { CID => 'CID' } },
            'survey.surveys' => {
                columns => { CID => 'CID' },
                join => {
                    'survey.answers' => { columns => { SID => 'SID' } },
                },
            },
        },
    }, {
        'title' => 'Switchers',
        'table' => 'CATool.Switchers',
        'key' => { 'id' => 'SesameID' },
        'where' => { 'ClType' => $params{$client->type()}{'switchers_type'} },
    }, {
		title => 'Email Messaging (appointment_schedule)',
        table => 'email_messaging.appointment_schedule',
        key => { 'unified_id' => 'client_id' },
    }, {
		title => 'Email Messaging (patient_access_token)',
        table => 'email_messaging.patient_access_token',
        key => { 'unified_id' => 'client_id' },
    }, {
		title => 'Email Messaging (patient_referral)',
        table => 'email_messaging.patient_referral',
        key => { 'unified_id' => 'client_id' },
		join => {
            'email_messaging.patient_referral_mail' => { 'columns' => { 'id' => 'referral_mail_id' } },
		},
    }, {
		title => 'Email Messaging (reminder_settings)',
        table => 'email_messaging.reminder_settings',
        key => { 'unified_id' => 'client_id' },
    }, {
		title => 'Email Messaging (sending_queue)',
        table => 'email_messaging.sending_queue',
        key => { 'unified_id' => 'client_id' },
	});

if ($client->type() eq 'ortho') {
    push @remove_subs, ({
            title => 'client_info',
            table => $main_db_name.'.client_info',
            key => { id => 'ci_id' },
        }, {
            title => 'client_performance',
            table => $main_db_name.'.client_performance',
            key => { id => 'CID' },
        }, {
            title => 'client_profile',
            table => $main_db_name.'.client_profile',
            key => { id => 'CID' },
        }, {
            title => 'client_profiles',
            table => $main_db_name.'.client_profiles',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'deleted_mail',
            table => $main_db_name.'.deleted_mail',
            key => { id => 'dm_client_id' },
            type => 'many',
        }, {
            title => 'monthly email_growth',
            table => $main_db_name.'.email_growth',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'feature settings',
            table => $main_db_name.'.feature_settings',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'hits count',
            table => $main_db_name.'.hits_count',
            key => { id => 'hcount_dr_id' },
            type => 'many',
        }, {
            title => 'hits log',
            table => $main_db_name.'.hits_log',
            key => { id => 'hlog_dr_id' },
            type => 'many',
        }, {
            title => 'image_system',
            table => $main_db_name.'.image_system',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'birthday reminders settings',
            table => $main_db_name.'.hb_settings',
            key => { id => 'hbs_cl_id' },
            type => 'many',
        }, {
            title => 'internal: non email',
            table => $main_db_name.'.internal_none_email',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'internal: simple reports',
            table => $main_db_name.'.internal_reports',
            key => { id => 'cl_id' },
        }, {
            title => 'internal: spm',
            table => $main_db_name.'.internal_spm_reports',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'mail list queue',
            table => $main_db_name.'.mail_list_queue',
            key => { id => 'mlq_cl_id' },
            type => 'many',
        }, {
            title => 'new_opp',
            table => $main_db_name.'.new_opp',
            key => { id => 'cl_id' },
        }, {
            title => 'promotion log',
            table => $main_db_name.'.promotion_log',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'risk2',
            table => $main_db_name.'.risk2',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'risk history',
            table => $main_db_name.'.risk_mhistory',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'satellite: first table',
            table => $main_db_name.'.satellites',
            key => { id => 'cl_id' },
            type => 'many',
            join => { $main_db_name.'.satellites_uploads' => { columns => { s_id => 's_id' } } },
        }, {
            title => 'satellite: second table',
            table => $main_db_name.'.satellite',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'satellite: log',
            table => $main_db_name.'.satellite_log',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'send to friend log',
            table => $main_db_name.'.send2friend_log',
            key => { id => 'sfl_client_id' },
            type => 'many',
        }, {
            title => 'surveys',
            table => $main_db_name.'.surveys',
            key => { id => 'sur_dr_id' },
            type => 'many',
            join => { $main_db_name.'.suranswers' => { columns => { ans_sur_num => 'sur_num' } } },
        }, {
            title => 'MOS: 4',
            table => $main_db_name.'.MOS_4',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'MOS: 3',
            table => $main_db_name.'.MOS_3',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'client rename order',
            table => $main_db_name.'.client_rename_order',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'suspended client',
            table => $main_db_name.'.clients_suspended',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'invisalign',
            table => 'invisalign.Client',
            key => { id => 'sesame_cl_id' },
			join => {
				'invisalign.icp_doctors' => {
					'columns' 	=> { 'id' => 'client_id' },
					'join'		=> {
						'invisalign.icp_patients' => { 'columns' => { 'doctor_id' => 'id' } },
					},
				},
				'invisalign.Patient' => { 'columns' => { 'client_id' => 'client_id' } },
			},
        }, {
            title => 'sales resource',
            table => $main_db_name.'.sales_resource',
            key => { id => 'cl_id' },
        }, {
            title => 'sales resource quotes',
            table => $main_db_name.'.sales_resourse_quotes',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'upload: main table',
            table => $main_db_name.'.upload',
            key => { id => 'upl_cl_id' },
            type => 'many',
        }, {
            title => 'upload: errors',
            table => $main_db_name.'.upload_errors',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'upload: last status',
            table => $main_db_name.'.upload_last',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'upload: summary',
            table => $main_db_name.'.upload_sum',
            key => { id => 'us_cl_id' },
            type => 'many',
        }, {
            title => 'upload: tasks',
            table => $main_db_name.'.upload_tasks',
            key => { id => 'client_id' },
            type => 'many',

        });
} else {
    push @remove_subs, ({
            title => 'delivery log',
            table => $main_db_name.'.delivery_log',
            key => { id => 'cl_id' },
        }, {
            title => 'feature settings',
            table => $main_db_name.'.client_features',
            key => { id => 'client_id' },
        }, {
			title => 'inv_clients',
			table => $main_db_name.'.inv_clients',
			key => { id => 'dental_cl_id' },
			join => {
				$main_db_name.'.icp_doctors' => {
					'columns' 	=> { 'id' => 'id' },
					'join'		=> {
						$main_db_name.'.icp_patients' => { 'columns' => { 'doctor_id' => 'id' } },
					}
				},
				$main_db_name.'.inv_patients' => { 'columns' => { 'client_id' => 'id' } },
				$main_db_name.'.inv_send2friend' => { 'columns' => { 'client_id' => 'id' } },
				$main_db_name.'.inv_send2referring' => { 'columns' => { 'client_id' => 'id' } },
				$main_db_name.'.inv_texts' => { 'columns' => { 'client_id' => 'id' } },
			},
		}, {
            title => 'sales resource',
            table => $main_db_name.'.sales_resource',
            key => { id => 'cl_id' },
        }, {
            title => 'sales resource quotes',
            table => $main_db_name.'.sales_resource_quotes',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'upload: main table',
            table => $main_db_name.'.upload',
            key => { id => 'cl_id' },
            type => 'many',
        }, {
            title => 'upload: errors',
            table => $main_db_name.'.upload_errors',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'upload: last status',
            table => $main_db_name.'.upload_last',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'upload: tasks',
            table => $main_db_name.'.upload_tasks',
            key => { id => 'client_id' },
            type => 'many',
        }, {
            title => 'upload: summary',
            table => $main_db_name.'.upload_trace',
            key => { id => 'client_id' },
            type => 'many',
        });
}

$logger->info("going to check [".scalar(@remove_subs)."] tables or more");



for my $t (@remove_subs) {
    my  $dbi = DB::get_dbi();

    unless (DB::check_table_exists($t->{table})) {
        $logger->warn("table [$t->{table}] not found ");
        next;
    }

    my  @where_cond =
            map {$t->{key}{$_}.'='.$dbi->quote($client->$_())}
            grep {defined $client->$_()} keys %{ $t->{key} };

    unless (@where_cond) {
        $logger->error("no keys found for: ".$t->{title});
        next;
    }

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
            $logger->info("clear: ".$t->{title});
            do_table_clear($t->{table}, $where);
        }
    }

    if (exists $t->{join}) {
        clear_join_table($dbi, $t->{join}, $t->{table}, $where);
    }
}

sub clear_join_table {
    my  ($dbi, $join_data, $table_name, $where) = @_;

    while (my ($join_tn, $join_params) = each %$join_data) {
        unless (DB::check_table_exists($join_tn)) {
            $logger->warn("join table [$join_tn] not found ");
            next;
        }
        my  @table_cond;
        my  %column_cond;
        my  $qr = $dbi->prepare("SELECT ".(join ', ', values %{ $join_params->{columns} })." FROM $table_name WHERE $where");
        $qr->execute();
        while (my $r = $qr->fetchrow_hashref()) {
            my  @cond;
            while (my ($join_col, $prim_col) = each %{ $join_params->{columns} }) {
                #if ($join_col =~ m/%s/) {
                #    push @cond, sprintf($join_col, $r->{$prim_col});
                #} else {
                #    push @cond, $join_col.'='.$dbi->quote($r->{$prim_col});
                #}
                push @cond, $join_col.'='.$dbi->quote($r->{$prim_col});
                push @{ $column_cond{$join_col} }, $dbi->quote($r->{$prim_col});
            }
            push @table_cond, '('.(join ' AND ', @cond).')';
        }
        if (@table_cond) {
            my  $join_where = join(' OR ', @table_cond);
            if ( keys(%column_cond) == 1 ) {
                my  ($k) = keys %column_cond;
                $join_where = $k." IN (".join(', ', @{ $column_cond{$k} }).")";
            }
            my  $count = $dbi->selectrow_array("SELECT COUNT(*) FROM $join_tn WHERE $join_where");
            if ($count > 0) {
                $logger->info("clear joined table: $join_tn");
                do_table_clear($join_tn, $join_where);
                if (exists $join_params->{join}) {
                    clear_join_table($dbi, $join_params->{join}, $join_tn, $join_where);
                }
            }
        } else {
            $logger->debug("no join records to delete in [$join_tn]");
        }
    }
}

if ($options{drop_db}) {
    $logger->logdie("can't drop db unless db name specified") unless defined $client->db();
    $logger->info("drop database: ".$client->db());
    do_db_clear($client->db());
}

if ($options{delete_folder}) {
    @remove_folders = grep {defined $_->{folder}} @remove_folders;
    $logger->error("no folders to delete") unless @remove_folders;
    for my $f (@remove_folders) {
        $logger->info("delete $f->{title} folder: ".$f->{folder});
        do_folder_clear($f->{folder}, $f->{title});
    }
}

flush_clear() if $options{do_remove};






{
    my  $back_up_folder = undef;
    my  $back_up_db_file = undef;

    sub _init_back_up_folder {
        unless ($back_up_folder) {
            $back_up_folder = defined $client->db() ?
                '_db_'.$client->db() :
                '_id_'.$client->id()."_".$client->type();
            my  @tt = (localtime())[0..5];
            $tt[5] += 1900;
            $tt[4] ++;
            $back_up_folder .= sprintf('_%04d%02d%02d%02d%02d%02d_backup', reverse(@tt));
            mkdir($back_up_folder) or $logger->logdie("can't create folder [$back_up_folder]: $!");
        }
    }

    my  @shell_commands;
    my  @sql_commands;

    sub do_table_clear {
        my  ($table, $where) = @_;


        if ($options{backup_db}) {
            my  $dbi = DB::get_dbi();
            _init_back_up_folder();
            unless ($back_up_db_file) {
                $back_up_db_file = IO::File->new();
                $back_up_db_file->open(File::Spec->catfile($back_up_folder, "databases.sql"), ">")
                    or $logger->logdie("can't create file in [$back_up_folder]: $!");
                $back_up_db_file->print("-- this file is created by sesame uninstall script (revision $revision)\n\n");
            }
            my  $qr = $dbi->prepare("SELECT * FROM $table WHERE $where");
            $qr->execute();
            $back_up_db_file->print("-- table $table\n");
            while (my $r = $qr->fetchrow_hashref()) {
                my  $sql = "INSERT INTO $table (".join(', ', keys %$r).") VALUES (".join(', ', map {$dbi->quote($_)} values %$r).");";
                $back_up_db_file->print("$sql\n");
            }
            $back_up_db_file->print("\n");
        }

        my  $sql = "DELETE FROM $table WHERE $where";
        $logger->debug("SQL: $sql");
        push @sql_commands, $sql;
    }

    sub do_db_clear {
        my  ($db_name) = @_;

        if ($options{backup_db}) {
            _init_back_up_folder();
            my  $cmd = qq(mysqldump "-h$options{db_host}" "-u$options{db_user}" "-p$options{db_password}" $db_name);
            $cmd .= ' > "'.File::Spec->catfile($back_up_folder, "client_db_$db_name.sql").'"';

            $logger->debug("CMD: $cmd");
            system($cmd);
        }
        my  $cmd = qq(mysqladmin "-h$options{db_host}" "-u$options{db_user}" "-p$options{db_password}" -f drop $db_name);
        $logger->debug("CMD: $cmd");
        push @shell_commands, $cmd;
    }

    sub do_folder_clear {
        my  ($folder, $name) = @_;

        unless (-d $folder) {
            $logger->error("folder [$folder] doesn't exists");
            return;
        }

        if ($options{backup_folders}) {
            _init_back_up_folder();
            my  $dir = File::Spec->catfile($back_up_folder, $name);
            mkdir($dir) or $logger->logdie("can't create folder [$dir]: $!");
            my  $cmd = qq(cp -r "$folder" "$dir");
            $logger->debug("CMD: $cmd");
            system($cmd);
        }

        my  $cmd = qq(rm -rf "$folder");
        $logger->debug("CMD: $cmd");
        push @shell_commands, $cmd;
    }

    sub flush_clear {
        if (@sql_commands) {
            $logger->info("clearing ".@sql_commands." tables".(@sql_commands==1?'':'s'));
            my  $dbi = DB::get_dbi();
            $dbi->do($_) for @sql_commands;
        }
        if (@shell_commands) {
            $logger->info("executing ".@shell_commands." shell command".(@shell_commands==1?'':'s'));
            system($_) for @shell_commands;
        }
    }
}


package DB;

sub check_table_exists {
    my  ($db_name, $table_name) = @_;
    if (@_ == 1) {
        ($db_name, $table_name) = split /\./, $db_name, 2;
    }

    return 0 unless check_db_exists($db_name);

    my  $dbi = get_dbi();
    return length $dbi->selectrow_array("SHOW TABLES FROM `".$db_name."` LIKE ".$dbi->quote($table_name));
}

sub check_db_exists {
    my  ($db_name) = @_;

    my  $dbi = get_dbi();
    return length $dbi->selectrow_array("SHOW DATABASES LIKE ".$dbi->quote($db_name));
}



{
    my  $dbi = undef;
    sub get_dbi {
        unless ($dbi) {
            $logger->debug("connecting to DB server [$options{db_host}]");
            $dbi = DBI->connect('DBI:mysql:host='.$options{db_host}, $options{db_user}, $options{db_password}, {
                    RaiseError => 1,
                    ShowErrorStatement => 1,
                });
        }
        return $dbi;
    }
}

package Client;

sub new {
    my  ($class, $params) = @_;

    my  $self = bless {
            id => undef,
            db => undef,
            type => undef,
            %$params,
            _logger => Log::Log4perl->get_logger(__PACKAGE__),
        }, $class;

    return $self;
}

sub as_string {
    my  ($self) = @_;

    return join ' ', map {"$_ [$self->{$_}]"} grep {$_ !~ /^_/ && defined $self->{$_}} keys %$self;
}

sub _get_client_param {
    my  ($self, $key, $col, $name) = @_;

    unless (defined $self->{$key}) {
        my  $dbi = DB::get_dbi();
        my  $main_db = $self->get_param('main_db_name');
        $self->{$key} = $dbi->selectrow_array("SELECT $col FROM ".$main_db.".clients WHERE ".$self->_get_client_where());
        $self->{_logger}->error("client $name is not set") unless $self->{$key};
    }
    return $self->{$key};
}

sub id {
    my  ($self) = @_;

    return $self->_get_client_param('id', 'cl_id', 'id');
}

sub unified_id {
    my  ($self) = @_;

	my $id = $self->id();
	if ($self->type() eq 'ortho') {
		$id = 'o'.$id;
	} elsif ($self->type() eq 'dental') {
		$id = 'd'.$id;
	} else {
		die "unknow client type [".$self->type()."]";
	}
    return $id;
}

sub db {
    my  ($self) = @_;

    return $self->_get_client_param('db', 'cl_mysql', 'db name');
}

sub web_folder {
    my  ($self) = @_;

    return $self->_get_client_param('web_folder', 'cl_pathw', 'web folder');
}

sub upload_folder {
    my  ($self) = @_;

    return $self->_get_client_param('upload_folder', 'cl_pathl', 'upload folder');
}

sub image_folder {
    my  ($self) = @_;

    unless ($self->{image_folder}) {
        if (defined $self->username()) {
            $self->{image_folder} = File::Spec->catfile($ENV{SESAME_WEB}, 'image_systems', $self->username());
        }
#        my  $dbi = DB::get_dbi();
#        my  $t = $self->type();
#        $self->{_logger}->logdie("need client type to get image folder") unless defined $t;
#        my  $id = $self->id();
#        $self->{_logger}->logdie("need client id to get image folder") unless defined $id;
#
#        my  $qr = $dbi->prepare(<<SQL);
#SELECT username FROM si_upload.Clients c, si_upload.ImageSystems i
#WHERE i.id=image_sys_type AND outer_id=? AND category=? LIMIT 1
#SQL
#        $qr->execute($id, $params{$t}{si_type});
#        my  $arr = $qr->fetchall_arrayref();
#        if (@$arr) {
#            $self->{image_folder} = File::Spec->catfile($ENV{SESAME_WEB}, 'image_systems', $arr->[0]);
#        }
    }
    return $self->{image_folder};
}


sub _get_client_where {
    my  ($self) = @_;

    my  $dbi = DB::get_dbi();

    return (defined $self->{id} ?
        "cl_id=".$dbi->quote($self->{id}) :
        (defined $self->{db} ? "cl_mysql=".$dbi->quote($self->{db}) :
            $self->{_logger}->logdie("don't know db name or db id")));
}

sub type {
    my  ($self) = @_;

    unless (defined $self->{type}) {
        my  $dbi = DB::get_dbi();
        $self->{_logger}->warn("client type is not set");
        if ($dbi->selectrow_array("SELECT COUNT(*) FROM ".$params{ortho}{main_db_name}.".clients WHERE ".$self->_get_client_where())) {
            $self->{_logger}->debug("client found in ortho");
            $self->{type} = 'ortho';
        } elsif ($dbi->selectrow_array("SELECT COUNT(*) FROM ".$params{dental}{main_db_name}.".clients WHERE ".$self->_get_client_where())) {
            $self->{_logger}->debug("client found in dental");
            $self->{type} = 'dental';
        } else {
            $logger->error("can't determine client type by db [".$self->_get_client_where()."]");
        }
    }
    return $self->{type};
}


sub username {
    my  ($self) = @_;

    unless (defined $self->{username}) {
        my  $dbi = DB::get_dbi();
        my  $t = $self->type();
        #$self->{_logger}->logdie("need client type to find db name") unless defined $t;
        if ($t eq 'ortho') {
            $self->{username} = $dbi->selectrow_array("SELECT cl_username FROM ".$params{$t}{main_db_name}.".clients WHERE ".$self->_get_client_where());
        } else {
            $self->{username} = $self->db();
        }
        $self->{_logger}->warn("username is unknown") unless defined $self->{username};
    }
    return $self->{username};
}

sub hhf_guid {
    my  ($self) = @_;

    unless (defined $self->{hhf_guid}) {
        my  $dbi = DB::get_dbi();
        my  $db = $self->db();
        my  $tn = $self->get_param('profile_table');

        if (DB::check_table_exists($db, $tn)) {
            $self->{hhf_guid} = $dbi->selectrow_array("SELECT SVal FROM `$db`.`$tn` WHERE PKey='HHF->GUID'");
        } else {
            $self->{_logger}->warn("table [$tn] doesn't exists in [$db]");
        }
    }
    return $self->{hhf_guid};
}

sub sms_guid {
    my  ($self) = @_;

    unless (defined $self->{sms_guid}) {
        my  $dbi = DB::get_dbi();
        my  $db = $self->db();
        my  $tn = $self->get_param('profile_table');

        if (DB::check_table_exists($db, $tn)) {
            $self->{sms_guid} = $dbi->selectrow_array("SELECT SVal FROM `$db`.`$tn` WHERE PKey='SMS.user_id'");
        } else {
            $self->{_logger}->warn("table [$tn] doesn't exists in [$db]");
        }
    }
    return $self->{sms_guid};
}

sub get_param {
    my  ($self, $param_name) = @_;

    my  $t = $self->type();
    $self->{_logger}->logdie("need client type to find [$param_name]") unless defined $t;
    return $params{$t}{$param_name};
}

sub srm_folder {
    my  ($self) = @_;

    unless ($self->{srm_folder}) {
        if (defined $self->db()) {
            $self->{srm_folder} = File::Spec->catfile($ENV{SESAME_WEB}, 'sesame_store', $self->db());
        }
    }
    return $self->{srm_folder};
}
