require 'pp'

node.default.java.install_flavor = 'openjdk'
node.default.java.jdk_version = 8
node.default.jenkins.master.install_method = 'package'
node.set.jenkins.master['jvm_options'] = '-Djenkins.install.runSetupWizard=false'
node.debug_value('jvm_options')


node.default.jenkins.user.thunter.fullname = 'Teo Hunter'
node.default.jenkins.user.thunter.email = 'thunter@sesamecommunications.com'
node.default.jenkins.user.thunter.password = 'sesame948'
node.default.jenkins.user.thunter.public_key = ['ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIBQHj83pWDfElfPMQ9aNKrFiZB8oZvCyWQPwMEnXbqawScd0DruAtE0jxsyzJCThyDmfoOatvdagF5QGbEnIhwDGxQ5oh4WL8wiMeBnKNAxfP69dN0rWDYmMa9c4mrV7u1qLLnPoUnnR/9cHdC0xfibxeRT10LTiA1oXT79XHOVzw== rsa-key-20120608']


node.default.jenkins.user.astighall.fullname = 'Annalise Stighall'
node.default.jenkins.user.astighall.email = 'thunter@sesamecommunications.com'
node.default.jenkins.user.astighall.password = 'sesame733'
node.default.jenkins.user.astighall.public_key = ['ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDba8TuFIdOD4R0qzqd/3pRfTHuv59pWAXarVn1hR4T2UaXDzTVb6tUK2ByHWPc5WOGwhq+hz1pEi94p2H6Nn9wpHXAFFfR8CtW/LeajfV/skSaSaPbAsgDp8AQrl+LF/szZ/9lGdYHxOOc99zyKiYASjFY4txq3xTLgYGXNZyceQuFVjTVk5GUgM+1DFeTsvB2zGQV05ZcTRJ6uIekLYzNZH4Ax/oODewlToxtoh/0kIvXpn/0eXFxVyoZ9ppJjZKiR1Qv3SVhLZM4smha8qx8LDbNvAyfgPclUPTbKbN0cmh1gXKLbNm1SPU7GHnOFIk6bj4ngU9FAE4Lsk8sqai9 astighall@argon']

node.default.jenkins.user.abowhill.fullname = 'abowhill'
node.default.jenkins.user.abowhill.email = 'abowhill@sesamecommunications.com'
node.default.jenkins.user.abowhill.password = 'sesame812'
node.default.jenkins.user.abowhill.public_key = ['ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAj7blN7ocjtXFdc8E45R+Jet7+gTgM1YbCpLsL1IiZXJEwQvALE7P7zU8OOeiv3QO7cEd2E3t0zWjBDwha+W9GGTPtGEK/9gPle3uhRTC7U4406YZpwkyGc/lE1N3b6+kXAlbDCoL8E3XadWuyBLnaEA2cRWUX5aANGD20A/cGAQPHuAcTa9L7WxTv7izhL7G/G+jgooR+1j9xQGB/y4hFtjeorCwN56GQrx2qZZcoWj1do7+8YvwVSJFqzchEaQvHGh6Opz+yFLBffkJ173KlwtB/IMyd0P3V9zaJz/zeepdnT6Z4wx45Yuw+qazljosb3J9sLeP/ZWebK3NiYwbbw==']
#node.set['jenkins']['master']['jenkins_args'] = '--argumentsRealm.roles.$ADMIN_USER=admin'
#node.set['jenkins']['master']['jenkins_args'] = '--argumentsRealm.passwd.$ADMIN_USER=sesame'
#node.set.jenkins.master['jenkins_args'] ='-Djenkins.install.runSetupWizard=false'

#env 'JENKINS_PORT' do
#   value "Hellpoo"
#end
#node.default.jenkins.master_version =
#node.set['jenkins']['java'] = '/usr/lib/jvm/java-1.8.0'
