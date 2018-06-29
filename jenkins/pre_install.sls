# Key
jenkins.apt.key:
  cmd.run:
    - name: 'wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | apt-key add -'
    - user: root

# Source
jenkins.apt.source:
  cmd.run:
    - name: "sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'"
    - user: root
    - require:
      - cmd: jenkins.apt.key
