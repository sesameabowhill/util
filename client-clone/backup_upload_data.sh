## $Id: backup_upload_data.sh 883 2009-06-23 23:15:58Z ivan $

db_name=$1
archive_file=$2

if test ! "$db_name" -o ! "$archive_file"
then
	echo "Usage: $0 <client_db> <archive_file>"
	exit 1
fi

db_host=$SESAME_DB_SERVER
db_user=roadmin
db_password=mdu3hw

mysql_cmd="mysql --skip-column-names -p$db_password -u$db_user -h$db_host"

is_ortho=`$mysql_cmd -e "SELECT count(*) FROM sesameweb.clients WHERE cl_mysql='$db_name'"`
is_dental=`$mysql_cmd -e "SELECT count(*) FROM dentists.clients WHERE cl_mysql='$db_name'"`
if test $is_ortho = 1
then
	echo "ortho client [$db_name]"
	cl_id=`$mysql_cmd -e "SELECT cl_id FROM sesameweb.clients WHERE cl_mysql='$db_name'"`
	source_folder=/home/sesame/uploader/data/backup/$cl_id
elif test $is_dental = 1
then
	echo "dental client [$db_name]"
	cl_id=`$mysql_cmd -e "SELECT cl_id FROM dentists.clients WHERE cl_mysql='$db_name'"`
	source_folder=/home/sesame/uploader_dental/data/backup/$cl_id
else
	echo "can't find client [$db_name]"
	exit 2
fi

if test -e $source_folder
then
	echo "archive [$source_folder] -> [$archive_file]"
	tar czfv $archive_file --absolute-names $source_folder/*
else
	echo "folder [$source_folder] doesn't exists"
fi