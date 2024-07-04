import subprocess
import logging

log = logging.getLogger(__name__)
def_vscode_cmd='C:\\Program Files\\Microsoft VS Code\\bin\\code.cmd'

def install_extension(extension, version=None, vscode_cmd=def_vscode_cmd):
    """
    Install a VSCode extension using the specified extension ID
    """
    if version:
        extension = f"{extension}@{version}"

    cmd = [vscode_cmd, "--install-extension", extension , "--force"]
    try:
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        output_str = output.decode()  # Convert bytes to string
        if "not found" in output_str or "Failed Installing" in output_str:
            print("in not found condition")
            return {'result': False, 'message': output_str}
        
        return {'result': True, 'message': output_str}
    except subprocess.CalledProcessError as e:
        log.error(f"Failed to install extension {extension}: {e.output}")
        return {'result': False, 'message': e.output.decode()}


def uninstall_extension(extension, version=None, vscode_cmd=def_vscode_cmd):
    """
    Install a VSCode extension using the specified extension ID
    """
    if version:
        extension = f"{extension}@{version}"
    cmd = [vscode_cmd, "--uninstall-extension", extension]
    try:
        subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        return {'result': True, 'message': f"Extension {extension} uninstalled successfully."}
    except subprocess.CalledProcessError as e:
        log.error(f"Failed to uninstall extension {extension}: {e.output}")
        return {'result': False, 'message': e.output.decode()}

def list_extensions(vscode_cmd=def_vscode_cmd):
    """
    List all installed VSCode extensions
    Returns them as a list of tuples (ext, version)
    Example:
    extension list = [
        ('d-biehl.robotcode', '0.83.3'),
        ('ms-python.debugpy', '2024.6.0'),
        ('ms-python.python', '2024.6.0'),
        ('ms-python.vscode-pylance', '2024.6.1')]
    """
    cmd = [vscode_cmd, "--list-extensions", '--show-versions']
    try:
        ret = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        ret = ret.decode().strip()
        # vscode command sucessfull but no extensions installed
        if ret == "":
            extension_list = []
        # vscode command sucessfull, extensions listed and transformed into list of tuples
        else:  
            extension_list = [(ext.split('@')[0], ext.split('@')[1]) for ext in ret.split('\n')]
        return extension_list
        
    except subprocess.CalledProcessError as e:
        log.error(f"Failed to list extensions: {e.output}")
        return []
