{%- from "jenkins/map.jinja" import master with context %}
{%- if master.ssl.enabled %}

jenkins.ssl.key:
  file.managed:
    - name: /var/lib/jenkins/{{ master.ssl.fileName }}.pem
    - source: {{ master.ssl.key }}
    - mode: 0644

jenkins.ssl.certificate:
  file.managed:
    - name: /var/lib/jenkins/{{ master.ssl.fileName }}.crt
    - source: {{ master.ssl.chainCert }}
    - mode: 0644

jenkins.ssl.pkcs12:
  cmd.run:
    - name: 'openssl pkcs12 -inkey {{ master.ssl.fileName }}.pem -in {{ master.ssl.fileName }}.crt -export -out keys.pkcs12'
    - unless: 'test -e /var/lib/jenkins/keys.pkcs12'
    - cwd: /var/lib/jenkins
    - user: root
    - require:
      - file: jenkins.ssl.key
      - file: jenkins.ssl.certificate

jenkins.ssl.keystore:
  cmd.run:
    - name: 'keytool -importkeystore -srckeystore keys.pkcs12 -srcstoretype pkcs12 -destkeystore jenkins.jks -deststoretype pkcs12'
    - unless: 'test -e /var/lib/jenkins/jenkins.jks'
    - cwd: /var/lib/jenkins
    - user: root
    - require:
      - cmd: jenkins.ssl.pkcs12

jenkins.ssl.service:
  service.running:
  - name: {{ master.service }}
  - watch:
    - cmd: jenkins.ssl.keystore

{%- endif %}
