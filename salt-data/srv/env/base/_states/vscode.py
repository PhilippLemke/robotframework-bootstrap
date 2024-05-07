def __virtual__():
    return 'vscode'

def extension_installed(name, install_path=None, version=None):
    """
    Ensure that a VSCode extension is installed
    """
    ret = {'name': name,
           'changes': {},
           'result': False,
           'comment': ''}

    comment = None
    extension_installed = __salt__['vscode.list_extensions']()

    # Example data
    #[('d-biehl.robotcode', '0.79.0'),
    # ('korekontrol.saltstack', '0.0.9'),
    # ('ms-python.debugpy', '2024.6.0'),
    # ('ms-python.python', '2024.4.1'),
    # ('ms-python.vscode-pylance', '2024.4.1'),
    # ('vscodevim.vim', '1.27.1')]
    #name=d-biehl.robotcode@0.79.0

    ext_org_name = f"{name}"
    if "@" in name:
        name_parts = name.split('@')
        name = name_parts[0]
        if not version:
            version = name_parts[-1]

    for ext, cur_version in extension_installed:
        if name == ext:
            #print(f"version={version} cur_version={cur_version}")
            if not version:
                ret['result'] = True
                ret['comment'] = f"Extension {name} is already installed."
                return ret
            elif version == cur_version:
                ret['result'] = True
                ret['comment'] = f"Extension {name} is already installed in desired version {version}"
                return ret
            else:
                comment = f"Extension {name} is already installed but NOT in desired version {version}\n"

    if __opts__['test']:
        ret['comment'] = f"Extension {name} will be installed."
        return ret

    if install_path:
        ext_org_name = f"{install_path}/{name}-{version}.vsix"

    install_info = __salt__['vscode.install_extension'](ext_org_name)
    if install_info['result']:
        ret['result'] = True
        ret['changes'][name] = 'Installed'
        if comment:
            ret['comment'] = comment + install_info['message']
        else:
            ret['comment'] = install_info['message']
    else:
        ret['comment'] = install_info['message']

    return ret
