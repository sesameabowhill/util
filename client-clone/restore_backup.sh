## $Id: restore_backup.sh 1999 2010-04-27 15:25:09Z ivan $

db_password=higer4
db_user=admin
file_name=$1
db_name=$2
tmp_folder=$3

if test ! "$file_name"
then
    echo "Usage: $0 <backup_file_name> [client_db] [temp_folder]"
    exit
fi

if test ! "$db_name"
then
    db_name=`perl -e "'$file_name' =~ m/_client_data_backup_(\w+)_\d+\.tar\.gz/; print \\$1"`
    if test ! "$db_name"
    then
        echo "can't find database name in file name [$file_name]"
        exit
    fi
fi

if test ! "$tmp_folder"
then
    tmp_folder=~/tmp
fi

if test ! "$SESAME_SERVER"
then
    main_db_name=
    uninstall_cmd="perl uninstall.pl $db_name"
else
    main_db_name=sesame_db
    uninstall_cmd="perl -I$SESAME_ROOT/sesame/utils/ $SESAME_ROOT/sesame/utils/uninstall_member.pl --uninstall $db_name --data-backup-folder=$tmp_folder"
fi

echo "temp folder [$tmp_folder]"
echo "database [$db_name]"

echo "uninstall [$db_name]"
$uninstall_cmd

echo "extract [$file_name]"
mkdir "$tmp_folder/$file_name"
cp "$file_name" "$tmp_folder/$file_name/"
cd "$tmp_folder/$file_name/"
tar xzf "$file_name"

if test -e web
then
    echo "copy web files"
    cd web
    cp -r * $SESAME_WEB/
    cd ..
fi

if test -e SRM
then
    echo "copy SRM files"
    cd SRM
    cp -r * $SESAME_WEB/sesame_store
    cd ..
fi

if test -e "client_db_$db_name.sql"
then
    echo "create doctors database"
    mysqladmin -u$db_user -p$db_password create $db_name
    mysql -u$db_user -p$db_password -f $db_name < client_db_$db_name.sql
fi

if test -e databases.sql
then
    echo "copy main data"
    mysql -u$db_user -p$db_password -f $main_db_name < databases.sql
fi

echo "done"