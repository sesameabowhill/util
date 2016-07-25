require 'pp'

default['java']['install_flavor'] = 'openjdk'
default['java']['jdk_version']= 8
default['jenkins']['master']['install_method'] = 'package'
default['jenkins']['master']['jvm_options'] = '-Djenkins.install.runSetupWizard=false'

default['jenkins']['master']['port'] = 8080
default['jenkins']['master']['endpoint'] = "http://#{node['jenkins']['master']['host']}:#{node['jenkins']['master']['port']}"

default['passwords']['mysql'] = 'sesame'

## List of modules to install in Jenkins
## each row is :   [ shortname , version (or nil for latest), restart server after install T or F ]

node.default.jenkins.module.list = [
[ 'github-api', '1.76', true ],
   [ 'structs', '1.2', false ],
   [ 'git-client', nil, true ],
   [ 'bouncycastle-api', '1.648.3', false ],
   [ 'windows-slaves', '1.1', false ],
   [ 'zapper', '1.0.7', false ],
[ 'gradle', '1.25', false ],
   [ 'workflow-api', '2.1', true ],
[ 'workflow-scm-step', '2.2', false ],
[ 'pipeline-stage-view', '1.6', false ],
[ 'pipeline-build-step', '2.2', false ],
[ 'workflow-durable-task-step', '2.3', false ],
   [ 'pipeline-stage-step', '2.1', false ],
[ 'workflow-step-api', '2.2', true ],
[ 'workflow-support', '2.2', false ],
   [ 'workflow-basic-steps', '2.0', false ],
   [ 'pipeline-input-step', '2.0', false ],
   [ 'workflow-job', '2.3', false ],
[ 'workflow-cps-global-lib', '2.1', false ],
   [ 'workflow-step-api', '2.1', false ],
   [ 'workflow-cps', '2.9', true ],
   [ 'workflow-multibranch', '2.8', false ],
   [ 'maven-plugin', '2.13', true ],
   [ 'ant', nil, false ],
   [ 'pam-auth', '1.3', true ],
[ 'junit', '1.15', false ],
[ 'git', '2.5.2', true ],
[ 'git-server', '1.7', false ],
[ 'github', '1.20.0', false ],
   [ 'github-oauth', nil, true ],
   [ 'versionnumber', nil, false ],
   [ 'credentials', nil, true ],
   [ 'cloudbees-folder', '5.12', true ],
   [ 'mailer', nil, true ],
   [ 'email-ext', nil, false ],
   [ 'matrix-auth', nil, false ],
[ 'matrix-project', '1.7.1', false ],
   [ 'ssh-credentials', '1.12', false ],
   [ 'plain-credentials', '1.2', false ],
   [ 'external-monitor-job', nil, false ],
   [ 'nodenamecolumn', nil, false ],
   [ 'jobtype-column', nil, false ],
   [ 'greenballs', nil, false ],
   [ 'view-job-filters', nil, false ],
   [ 'dashboard-view', nil, false ],
   [ 'javadoc', '1.4', false ],
   [ 'instant-messaging', nil, false ],
   [ 'artifactdeployer', nil, false ],
   [ 'artifactory', nil, true ],
   [ 'copy-to-slave', nil, false ],
   [ 'slave-setup', nil, false ],
   [ 'ssh-slaves', nil, false ],
   [ 'slave-status', nil, false ],
   [ 'performance', nil, false ],
   [ 'cobertura', nil, false ],
   [ 'envfile', nil, false ],
   [ 'file-leak-detector', nil, false ],
   [ 'scm-api', '1.2', false ],
[ 'script-security', '1.21', false ],
   [ 'token-macro', '1.12.1', false ],
   [ 'durable-task', '1.10', false ],
   [ 'ace-editor', '1.1', false ],
   [ 'handlebars', '1.1.1', false ],
   [ 'jquery-detached', '1.2.1', false ],
   [ 'momentjs', '1.1.1', false ],
[ 'ivy', '1.26', false ],
[ 'config-file-provider', '2.11', false ],
[ 'durable-task', '1.11', false ],
   ]

