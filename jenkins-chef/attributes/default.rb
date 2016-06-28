require 'pp'

node.default.java.install_flavor = 'openjdk'
node.default.java.jdk_version = 8
node.default.jenkins.master.install_method = 'package'
node.set.jenkins.master['jvm_options'] = '-Djenkins.install.runSetupWizard=false'
node.debug_value('jvm_options')

#node.default.jenkins.user.thunter.fullname = 'Teo Hunter'
#node.default.jenkins.user.thunter.email = 'thunter@sesamecommunications.com'
#node.default.jenkins.user.thunter.password = 'sesame948'
#node.default.jenkins.user.thunter.public_key = ['ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIBQHj83pWDfElfPMQ9aNKrFiZB8oZvCyWQPwMEnXbqawScd0DruAtE0jxsyzJCThyDmfoOatvdagF5QGbEnIhwDGxQ5oh4WL8wiMeBnKNAxfP69dN0rWDYmMa9c4mrV7u1qLLnPoUnnR/9cHdC0xfibxeRT10LTiA1oXT79XHOVzw== rsa-key-20120608']
#
#node.default.jenkins.user.astighall.fullname = 'Annalise Stighall'
#node.default.jenkins.user.astighall.email = 'thunter@sesamecommunications.com'
#node.default.jenkins.user.astighall.password = 'sesame733'
#node.default.jenkins.user.astighall.public_key = ['ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDba8TuFIdOD4R0qzqd/3pRfTHuv59pWAXarVn1hR4T2UaXDzTVb6tUK2ByHWPc5WOGwhq+hz1pEi94p2H6Nn9wpHXAFFfR8CtW/LeajfV/skSaSaPbAsgDp8AQrl+LF/szZ/9lGdYHxOOc99zyKiYASjFY4txq3xTLgYGXNZyceQuFVjTVk5GUgM+1DFeTsvB2zGQV05ZcTRJ6uIekLYzNZH4Ax/oODewlToxtoh/0kIvXpn/0eXFxVyoZ9ppJjZKiR1Qv3SVhLZM4smha8qx8LDbNvAyfgPclUPTbKbN0cmh1gXKLbNm1SPU7GHnOFIk6bj4ngU9FAE4Lsk8sqai9 astighall@argon']
#
#node.default.jenkins.user.abowhill.fullname = 'abowhill'
#node.default.jenkins.user.abowhill.email = 'abowhill@sesamecommunications.com'
#node.default.jenkins.user.abowhill.password = 'sesame812'
#node.default.jenkins.user.abowhill.public_key = ['ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAj7blN7ocjtXFdc8E45R+Jet7+gTgM1YbCpLsL1IiZXJEwQvALE7P7zU8OOeiv3QO7cEd2E3t0zWjBDwha+W9GGTPtGEK/9gPle3uhRTC7U4406YZpwkyGc/lE1N3b6+kXAlbDCoL8E3XadWuyBLnaEA2cRWUX5aANGD20A/cGAQPHuAcTa9L7WxTv7izhL7G/G+jgooR+1j9xQGB/y4hFtjeorCwN56GQrx2qZZcoWj1do7+8YvwVSJFqzchEaQvHGh6Opz+yFLBffkJ173KlwtB/IMyd0P3V9zaJz/zeepdnT6Z4wx45Yuw+qazljosb3J9sLeP/ZWebK3NiYwbbw==']

#node.set['jenkins']['master']['jenkins_args'] = '--argumentsRealm.roles.$ADMIN_USER=admin'
#node.set['jenkins']['master']['jenkins_args'] = '--argumentsRealm.passwd.$ADMIN_USER=sesame'

default['jenkins']['master']['port'] = 8080
default['jenkins']['master']['endpoint'] = "http://#{node['jenkins']['master']['host']}:#{node['jenkins']['master']['port']}"

## List of modules to install in Jenkins
## each row is :   [ shortname , version (or nil for latest), restart server after install T or F ]

node.default.jenkins.module.list = [
   [ 'structs', '1.2', false ],
   [ 'git-client', nil, true ],
   [ 'bouncycastle-api', '1.648.3', false ],
   [ 'windows-slaves', '1.1', false ],
   [ 'zapper', '1.0.7', false ],
   [ 'gradle', '1.24', false ],
   [ 'workflow-api', '2.1', true ],
   [ 'workflow-scm-step', '2.1', false ],
   [ 'pipeline-stage-view', '1.4', false ],
   [ 'pipeline-build-step', '2.1', false ],
   [ 'workflow-durable-task-step', '2.2', false ],
   [ 'pipeline-stage-step', '2.1', false ],
   [ 'workflow-step-api', '2.1', true ],
   [ 'workflow-support', '2.1', false ],
   [ 'workflow-basic-steps', '2.0', false ],
   [ 'pipeline-input-step', '2.0', false ],
   [ 'workflow-job', '2.3', false ],
   [ 'workflow-cps-global-lib', '2.0', false ],
   [ 'workflow-step-api', '2.1', false ],
   [ 'workflow-cps', '2.6', true ],
   [ 'workflow-multibranch', '2.8', false ],
   [ 'maven-plugin', '2.13', true ],
   [ 'ant', nil, false ],
   [ 'pam-auth', '1.3', true ],
   [ 'junit', '1.13', false ],
   [ 'git', '2.4.4', true ],
   [ 'git-server', '1.6', false ],
   [ 'github', '1.19.2', false ],
   [ 'github-api', '1.75', true ],
   [ 'github-oauth', nil, true ],
   [ 'versionnumber', nil, false ],
   [ 'credentials', nil, true ],
   [ 'cloudbees-folder', '5.12', true ],
   [ 'mailer', nil, true ],
   [ 'email-ext', nil, false ],
   [ 'matrix-auth', nil, false ],
   [ 'matrix-project', '1.7', false ],
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
   [ 'jabber', nil, false ],
   [ 'artifactdeployer', nil, false ],
   [ 'artifactory', nil, true ],
   [ 'copy-to-slave', nil, false ],
   [ 'slave-setup', nil, false ],
   [ 'ssh-slaves', nil, false ],
   [ 'slave-status', nil, false ],
   [ 'slack', nil, false ],
   [ 'performance', nil, false ],
   [ 'cobertura', nil, false ],
   [ 'envfile', nil, false ],
   [ 'file-leak-detector', nil, false ],
   [ 'scm-api', '1.2', false ],
   [ 'script-security', '1.19', false ],
   [ 'token-macro', '1.12.1', false ],
   [ 'durable-task', '1.10', false ],
   [ 'ace-editor', '1.1', false ],
   [ 'handlebars', '1.1.1', false ],
   [ 'jquery-detached', '1.2.1', false ],
   [ 'momentjs', '1.1.1', false ],
   [ 'durable-task', '1.10', false ],
   ]



