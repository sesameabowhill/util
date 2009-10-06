## $Id$
mysql_cmd="mysql -uadmin -phiger4 -h$SESAME_DB_SERVER -v"
temp_file=_voice_db
used_sb_file=_used_sb
cdyne_sb_file=_cdyne_sb

echo gather used soundbites
$mysql_cmd voice -e "select concat('~^',sound_id,'~') from DefaultSoundBites" > $temp_file
$mysql_cmd voice -e "select guid from autofills where guid != ''" >> $temp_file
$mysql_cmd voice -e "select guid from EndMessage where guid != ''" >> $temp_file
$mysql_cmd voice -e "select guid from OfficeNamePronunciation where guid != ''" >> $temp_file
$SESAME_ROOT/sesame/utils/install_utils/update_all_clients.pl all -f "$mysql_cmd %%client_db%% -e 'select sending_template from voice_schemes where voice_type=\"professional\";' >> $temp_file"

echo parse used soundbites
perl -e 'while(<>){while (m/~\^([^~]+)~/g) {$a{qq{$1\n}}=1} }; print sort keys %a' $temp_file > $used_sb_file

echo get CDyne soundbites
wget http://ws.cdyne.com/NotifyWS/PhoneNotify.asmx/ReturnSoundFileIDs -q --post-data=LicenseKey=F1A49B73-1B6D-4AA9-AF9A-D41FCFA08F89 -O - | perl -ne 'print qq($1\n) if m(<string>([^<]+)</string>)' > $cdyne_sb_file

echo compare
echo =====================================================
fgrep -ivwFf $cdyne_sb_file $used_sb_file
echo =====================================================
