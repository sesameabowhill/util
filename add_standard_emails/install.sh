dr_name=$1
echo installing to [$dr_name]

perl add_standard_emails.pl $dr_name
perl fix_external_links_in_standard.pl $dr_name

cp -rv img $SESAME_WEB
echo done

