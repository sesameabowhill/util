sudo /etc/init.d/pp-snapshot stop
sudo /etc/init.d/ppng stop
sudo rm /home/sites/wrapper/logs/pp-snapshot.vpc-test-stagemigration-01.sesamecom.com.log
cd /home/sites/artifacts/
perl get_build.pl pp-ng f-ppng --save-as-symlink=/home/sites/artifacts/pp-ng-jetty-console.war --delete-current-symlink-target
ls -l /home/sites/artifacts/pp-ng-jetty-console.war
sudo /etc/init.d/ppng start

