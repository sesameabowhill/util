name 'jenkinsjava'
maintainer 'Allan Bowhill'
maintainer_email 'abowhill@sesamecommunications.com'
license 'internal'
description 'Installs/Configures Jenkins on Java8'
long_description 'Installs/Configures Jenkins and Java8'
version '0.1.0'
issues_url 'http://www.sesamecommunications.com'
source_url 'http://www.sesamecommunications.com' 

depends 'ntp'
depends 'java', '~> 1.39.0'
depends 'maven', '~> 2.2.0'
depends 'git', '~> 4.3'
depends 'jenkins', '~> 2.5.0'
depends 'mysql', '~> 7.0'
#depends 'chef-sugar'