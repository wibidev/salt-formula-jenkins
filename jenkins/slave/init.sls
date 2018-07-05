{% from "jenkins/map.jinja" import slave with context %}

{%- if slave.enabled %}

{%- if slave.pbuilder is defined or slave.gpg is defined or slave.keystone is defined %}
include:
{%- if slave.pbuilder is defined %}
- jenkins.slave.pbuilder
{%- endif %}
{%- if slave.gpg is defined %}
- jenkins.slave.gpg
{%- endif %}
{%- if slave.keystone is defined %}
- jenkins.slave.keystone
{%- endif %}
{%- endif %}

{% if grains.os_family == 'Windows' %}

jenkins_user:
  user.present:
    - name: {{ slave.runner.name }}
    - password: {{ slave.runner.password }}
    - groups:
      - Administrators

jenkins_slave_home:
  file.directory:
    - name: {{ slave.jenkinshome }}
    - require:
      - user: jenkins_user

jenkins_slave_init_script:
  file.managed:
    - name: {{ slave.jenkinshome }}/deploy.ps1
    - source: salt://jenkins/files/slave/windows/deploy.ps1
    - template: jinja
    - require:
      - file: jenkins_slave_home

jenkins_slave_install:
  cmd.run:
    - name: '.\deploy.ps1 -a start'
    - unless: powershell.exe -ExecutionPolicy Bypass -command "if ( Get-Service {{ slave.service }} -ErrorAction SilentlyContinue ) { exit 0 } else { exit 1 }"
    - cwd: {{ slave.jenkinshome }}
    - shell: powershell
    - require:
      - file: jenkins_slave_init_script

jenkins_slave_service:
  service.running:
  - name: {{ slave.service }}
  - enable: true
  - require:
    - cmd: jenkins_slave_install
  - watch:
    - file: jenkins_slave_init_script

{% else %}

jenkins_slave_user:
  user.present:
  - name: jenkins
  - shell: /bin/bash
  - home: ' {%- if slave.remoteFs is defined %}{{ slave.remoteFs }}{%- else %}/var/lib/jenkins{%- endif %}'
  - require_in:
    {%- if slave.gpg is defined %}
    - file: jenkins_gpg_key_dir
    {%- endif %}
    {%- if slave.pbuilder is defined %}
    - file: /var/lib/jenkins/pbuilder
    {%- endif %}

{% if slave.pkgs %}
jenkins_slave_install:
  pkg.installed:
  - names: {{ slave.pkgs }}

{%- if grains.init == 'systemd' %}
jenkins_slave_init_script:
  file.managed:
    - name: /etc/systemd/system/jenkins-slave.service
    - source: salt://jenkins/files/slave/jenkins-slave.service
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: jenkins_slave_start_script
{%- endif %}

{% else %}

# No jenkins-slave package, use magic init script instead
jenkins_slave_init_script:
  file.managed:
    - name: {{ slave.init_script }}
    - source: salt://jenkins/files/slave/jenkins-slave
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - require:
      - file: jenkins_slave_start_script

{% endif %}

jenkins_slave_config:
  file.managed:
  - name: {{ slave.config }}
  - source: salt://jenkins/files/slave/default
  - user: root
  - group: root
  - template: jinja
  - require:
    {% if slave.pkgs %}
    - pkg: jenkins_slave_install
    {% else %}
    - file: jenkins_slave_init_script
    {% endif %}

jenkins_slave_start_script:
  file.managed:
  - name: /usr/local/bin/jenkins-slave
  - source: salt://jenkins/files/slave/jenkins-slave
  - user: root
  - group: root
  - mode: 755
  - template: jinja

jenkins_slave_logs:
  file.directory:
    - name: /var/log/jenkins
    - makedirs: True
    - user: jenkins
    - group: jenkins
    - require:
      - user: jenkins_slave_user

jenkins_slave_enable_service:
  cmd.run:
    - name: 'systemctl enable jenkins-slave.service'
    - unless: 'systemctl status jenkins-slave.service'
    - require:
      - file: jenkins_slave_logs
      {% if slave.pkgs %}
      - pkg: jenkins_slave_install
      {% else %}
      - file: jenkins_slave_init_script
      {% endif %}

jenkins_slave_service:
  service.running:
  - name: {{ slave.service }}
  - enable: true
  - require:
    - cmd: jenkins_slave_enable_service
  - watch:
    - file: jenkins_slave_config
    {% if not slave.pkgs %}
    - file: jenkins_slave_init_script
    {% endif %}

{%- if slave.get('sudo', false) %}
jenkins_slave_sudoer:
  file.managed:
  - name: /etc/sudoers.d/99-jenkins-user
  - source: salt://jenkins/files/slave/sudoer
  - template: jinja
  - user: root
  - group: root
  - mode: 440
  - require:
    - service: jenkins_slave_service
{%- endif %}

{%- endif %}

{% endif %}
