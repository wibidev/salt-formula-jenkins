{%- from "jenkins/map.jinja" import master with context %}
{%- if master.enabled %}
include:
- jenkins.master.service
{%- if master.users is defined %}
- jenkins.master.user
{%- endif %}
{%- if master.ssl is defined %}
- jenkins.master.ssl
{%- endif %}
{%- if master.plugins is defined %}
- jenkins.master.plugin
{%- endif %}
{%- endif %}
