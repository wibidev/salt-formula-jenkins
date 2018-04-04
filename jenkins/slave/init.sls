{% from "jenkins/map.jinja" import slave with context %}

{%- if slave.enabled %}

{%- if slave.pbuilder is defined or slave.gpg is defined or slave.keystone is defined %}
include:
{%- endif %}
{%- if slave.pbuilder is defined %}
- jenkins.slave.pbuilder
{%- endif %}
{%- if slave.gpg is defined %}
- jenkins.slave.gpg
{%- endif %}
{%- if slave.keystone is defined %}
- jenkins.slave.keystone
{%- endif %}

{% if slave.pkgs %}

jenkins_slave_install:
  pkg.installed:
  - names: {{ slave.pkgs }}

{% else %}

jenkins_slave_install:
  cmd.run:
    - name: "java -jar agent.jar -jnlpUrl http://{{ slave.master.host }}/computer/{{ slave.name }}/slave-agent.jnlp -jnlpCredentials '{{ slave.master.user }}:{{ slave.master.password }}'"
    - cwd: ' {%- if slave.remoteFs is defined %}{{ slave.remoteFs }}{%- else %}/var/lib/jenkins{%- endif %}'

{% endif %}

# No jenkins-slave package, use magic init script instead
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

{%- else %}

jenkins_slave_init_script:
  file.managed:
    - name: {{ slave.init_script }}
    - source: salt://jenkins/files/slave/init.d/jenkins-slave
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - require:
      - file: jenkins_slave_start_script

{%- endif %}

{{ slave.config }}:
  file.managed:
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

jenkins_slave_service:
  service.running:
  - name: {{ slave.service }}
  - watch:
    - file: {{ slave.config }}
  - enable: true
  - require:
    {% if slave.pkgs %}
    - pkg: jenkins_slave_install
    {% else %}
    - file: jenkins_slave_init_script
    {% endif %}

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

{%- if slave.get('sudo', false) %}

/etc/sudoers.d/99-jenkins-user:
  file.managed:
  - source: salt://jenkins/files/slave/sudoer
  - template: jinja
  - user: root
  - group: root
  - mode: 440
  - require:
    - service: jenkins_slave_service

{%- endif %}

{%- endif %}
