vscode:
  pkg.installed

{% vscode_extensions = salt['pillar.get']('vscode:extensions', []) %}

{% for ext in vscode_extensions -%}
install-vscode-ext-{{ ext }}:
  cmd.run:
    - name: code --install-extension {{ ext }}
{% endfor %}