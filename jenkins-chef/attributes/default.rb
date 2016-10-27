require 'pp'

default['jenkins']['master']['admin_user_names'] = 'sesameabowhill, thunter, astighall'
default['jenkins']['master']['ipaddress'] = '172.17.0.2'
default['jenkins']['master']['port'] = '8080'
default['java']['install_flavor'] = 'openjdk'
default['java']['jdk_version']= 8
default['jenkins']['master']['install_method'] = 'package'
default['jenkins']['master']['jvm_options'] = '-Djenkins.install.runSetupWizard=false'
#default['jenkins']['master']['endpoint'] = "http://#{node['jenkins']['master']['ipaddr_port_combo']}"

default['passwords']['mysql'] = 'sesame'
default['passwords']['jenkins'] = '7e26fb3e9cd207a5ccc85f399f8502167e6c762d'
default['passwords']['oauth']['clientid'] = '84389e1a195eee676128'
default['passwords']['oauth']['clientsecret'] = '4773bd184883cec9b4bd2bf7074d427758054fb4'




## List of modules to install in Jenkins
## each row is :   [ shortname , version (or nil for latest), restart server after install T or F ]

default['jenkins']['module']['list'] = [
[ 'workflow-scm-step', '2.2', true ],
   [ 'display-url-api','0.5', true ],
[ 'github-api', '1.79', true ],
[ 'structs', '1.5', true ],
   [ 'git-client', nil, true ],
   [ 'bouncycastle-api', '1.648.3', false ],
   [ 'windows-slaves', '1.2', false ],
   [ 'zapper', '1.0.7', false ],
   [ 'gradle', '1.25', false ],
[ 'workflow-api', '2.5', false ],
[ 'pipeline-stage-view', '2.1', false ],
[ 'pipeline-build-step', '2.3', true ],
[ 'workflow-durable-task-step', '2.5', true ],
[ 'pipeline-stage-step', '2.2', true ],
[ 'workflow-support', '2.10', true ],
[ 'workflow-basic-steps', '2.2', true ],
[ 'pipeline-input-step', '2.3', true ],
[ 'workflow-job', '2.8', true ],
[ 'workflow-step-api', '2.4', false ],
[ 'workflow-cps', '2.21', false ],
[ 'workflow-cps-global-lib', '2.4', false ],
[ 'pipeline-graph-analysis', '1.2', true ],
[ 'workflow-multibranch', '2.9', true ],
[ 'maven-plugin', '2.14', true ],
   [ 'ant', nil, false ],
   [ 'pam-auth', '1.3', true ],
[ 'junit', '1.19', true ],
[ 'git', '3.0.0', true ],
   [ 'git-server', '1.7', false ],
[ 'github', '1.22.3', false ],
   [ 'github-oauth', nil, true ],
   [ 'versionnumber', nil, false ],
   [ 'credentials', nil, true ],
[ 'cloudbees-folder', '5.13', true ],
   [ 'mailer', nil, true ],
   [ 'email-ext', nil, false ],
   [ 'matrix-auth', nil, false ],
   [ 'matrix-project', '1.7.1', false ],
   [ 'ssh-credentials', '1.12', false ],
[ 'plain-credentials', '1.3', true ],
   [ 'external-monitor-job', nil, false ],
   [ 'nodenamecolumn', nil, false ],
   [ 'jobtype-column', nil, false ],
   [ 'greenballs', nil, false ],
   [ 'view-job-filters', nil, false ],
   [ 'dashboard-view', nil, false ],
   [ 'javadoc', '1.4', false ],
   [ 'instant-messaging', nil, false ],
   [ 'artifactdeployer', nil, false ],
[ 'artifactory', '2.7.2', true ],
   [ 'copy-to-slave', nil, false ],
   [ 'slave-setup', nil, false ],
   [ 'ssh-slaves', nil, false ],
   [ 'slave-status', nil, false ],
   [ 'performance', nil, false ],
   [ 'cobertura', nil, false ],
   [ 'envfile', nil, false ],
   [ 'file-leak-detector', nil, false ],
[ 'scm-api', '1.3', true ],
[ 'script-security', '1.24', true ],
[ 'token-macro', '2.0', true ],
   [ 'durable-task', '1.10', false ],
   [ 'ace-editor', '1.1', false ],
   [ 'handlebars', '1.1.1', false ],
   [ 'jquery-detached', '1.2.1', false ],
   [ 'momentjs', '1.1.1', false ],
   [ 'ivy', '1.26', false ],
 [ 'config-file-provider', '2.13', true ],
   [ 'durable-task', '1.12', false ],
   ]

