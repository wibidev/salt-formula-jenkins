{%- from "jenkins/map.jinja" import master with context %}
{%- if master.enabled %}

jenkins_packages:
  pkg.installed:
  - names: {{ master.pkgs }}

jenkins_{{ master.config }}:
  file.managed:
  - name: {{ master.config }}
  - source: salt://jenkins/files/jenkins
  - user: root
  - group: root
  - template: jinja
  - require:
    - pkg: jenkins_packages

{%- if master.get('no_config', False) == False %}
{{ master.home }}/config.xml:
  file.managed:
  - source: salt://jenkins/files/config.xml
  - template: jinja
  - user: jenkins
  - watch_in:
    - service: jenkins_master_service
{%- endif %}

{%- if master.update_site_url is defined %}

{{ master.home }}/hudson.model.UpdateCenter.xml:
  file.managed:
  - source: salt://jenkins/files/hudson.model.UpdateCenter.xml
  - template: jinja
  - user: jenkins
  - require:
    - pkg: jenkins_packages

{%- endif %}

{%- if master.approved_scripts is defined %}

{{ master.home }}/scriptApproval.xml:
  file.managed:
  - source: salt://jenkins/files/scriptApproval.xml
  - template: jinja
  - user: jenkins
  - require:
    - pkg: jenkins_packages

{%- endif %}

{%- if master.email is defined %}

{{ master.home }}/hudson.tasks.Mailer.xml:
  file.managed:
  - source: salt://jenkins/files/hudson.tasks.Mailer.xml
  - template: jinja
  - user: jenkins
  - require:
    - pkg: jenkins_packages

{%- endif %}

{%- if master.get('sudo', false) %}

/etc/sudoers.d/99-jenkins-user:
  file.managed:
  - source: salt://jenkins/files/sudoer
  - template: jinja
  - user: root
  - group: root
  - mode: 440
  - require:
    - service: jenkins_master_service

{%- endif %}

{%- if pillar.jenkins.master.slaves is defined %}
{%- for slave in pillar.jenkins.master.slaves %}
jenkins_slave_{{ slave.name }}:
  file.managed:
    - name: /var/lib/jenkins/nodes/{{ slave.name }}/config.xml
    - source: salt://jenkins/files/config.slave.xml
    - makedirs: True
    - template: jinja
    - user: jenkins
    - context:
        slave: {{ slave }}
    - watch_in:
      - service: jenkins_master_service
{%- endfor %}
{%- endif %}

jenkins_master_service:
  service.running:
  - name: {{ master.service }}
  - watch:
    - file: jenkins_{{ master.config }}
    - file: {{ master.home }}/hudson.model.UpdateCenter.xml

jenkins_service_running:
  cmd.wait:
    - name: "i=0; while true; do curl -s -f http://localhost:{{ master.http.port }}/login >/dev/null && exit 0; [ $i -gt 60 ] && exit 1; sleep 5; done"
    - watch:
      - service: jenkins_master_service

{%- endif %}
