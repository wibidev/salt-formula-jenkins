{%- from "jenkins/map.jinja" import slave with context %}
{%- if slave.enabled %}
include:
- jenkins.slave.service
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
