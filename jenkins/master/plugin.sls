{% from "jenkins/map.jinja" import master with context %}

{{ master.home }}/updates:
  file.directory:
  - user: jenkins
  - group: nogroup

setup_jenkins_cli:
  cmd.run:
  - names:
    - wget http://localhost:{{ master.http.port }}/jnlpJars/jenkins-cli.jar
  - unless: "[ -f /root/jenkins-cli.jar ]"
  - cwd: /root
  - require:
    - cmd: jenkins_service_running

{%- for plugin in master.plugins %}

install_jenkins_plugin_{{ plugin.name }}:
  module.run:
    - jenkins.plugin_installed:
      - name: {{ plugin.name }}
    - require:
      - cmd: setup_jenkins_cli
      - cmd: jenkins_service_running

{%- endfor %}
