#!/usr/bin/perl
## $Id$

use strict;
use DBI;
use DateTime;
use DateTime::Format::MySQL;
use Hash::Util qw( lock_keys );

{
    my $sending_date = '2009-10-14'; #Set to today's date
    my $skip_date = '2009-10-14'; #set to yesterday
    my $sending_datetime = "2009-10-15 08:00:00";# set time to NOW+30 min. +
    my $dbi = connect1();
    my $calls = $dbi->selectall_arrayref(<<SQL, { Slice => {} }, "$sending_date 00:00:00", "$sending_date 23:59:59", "$skip_date%");
SELECT * FROM MessageHistory
WHERE 
	sent_type='transient' AND time2send >= ? AND time2send <= ? AND 
	unique_key not like ? AND event_datetime > NOW()
LIMIT 3000
SQL
    printf "going to resend [%d] calls\n", scalar @$calls;
        my $insert_q = $dbi->prepare(<<SQL);
insert into Queue (xml_request,time2send,cid,rec_id,rec_phone,message_type,unique_key,event_datetime)
values (?,?,?,?,?,?,?,?)
SQL
    my $delete_q = $dbi->prepare("delete from MessageHistory where id=?");
    my $xml_q = $dbi->prepare("select xml_request from XmlRequestHistory where message_history_id=?");
    my $sending_dt = DateTime::Format::MySQL->parse_datetime($sending_datetime);
    $sending_dt->set_time_zone('local');
    for my $call (@$calls) {
        lock_keys(%$call);
        $xml_q->execute($call->{'id'});
        my $xml = $xml_q->fetchrow_array();
        printf "get xml for [%d] call [%s] (%d)\n", $call->{'id'}, $call->{'unique_key'}, length $xml;
        my $dt = get_randomized_time_to_send($sending_dt);
        $dt->set_time_zone('UTC');
        my $dt_str = $dt->ymd().'T'.$dt->hms().'.000Z';
        if ($xml =~ s,(<UTCScheduledDateTime>)[^<]+(</UTCScheduledDateTime>),$1$dt_str$2,) {
            printf "set sending date to [%s]\n", $dt_str;
            $insert_q->execute($xml, $sending_datetime, @$call{'cid','rec_id','rec_phone','message_type','unique_key','event_datetime'});
            printf "inserted into queue [%d]\n", $dbi->{'mysql_insertid'};
            $delete_q->execute($call->{'id'});
        }
#use Data::Dumper;
#print Dumper($dt->strftime( '%s' ));

##<UTCScheduledDateTime>2008-09-10T14:10:00.000Z</UTCScheduledDateTime>
    }
}

sub connect1 {

    return DBI->connect(
		"DBI:mysql:database=voice;host=$ENV{SESAME_DB_SERVER}",
		'admin',
		'higer4',
		{
			'RaiseError' => 1,
			'ShowErrorStatement' => 1,
			'PrintError' => 0,
		}
	);
}

sub get_randomized_time_to_send {
    my $time_to_send_ref = shift;

    my $minutes_interval = ( int rand 2 ) ?
        -( int rand 15 + 1) :
         int rand 16;

    my $duration_ref = DateTime::Duration->new(
        'minutes' => $minutes_interval,
    );

    return $time_to_send_ref + $duration_ref;
}
