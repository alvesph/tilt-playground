"""Lista os diretórios imediatos da raiz configurada, sem percorrer os projetos."""
import json
from pathlib import Path
import sys


def discover(config_path):
    config_path = Path(config_path).resolve()
    config = json.loads(config_path.read_text())
    if not isinstance(config, dict) or not isinstance(config.get('path'), str) or not config['path'].strip():
        raise ValueError('projects.json deve conter um único diretório base: {"path": "/caminho/dos/projetos"}')
    base = Path(config['path']).expanduser()
    if not base.is_absolute():
        base = config_path.parent / base
    base = base.resolve()
    if not base.is_dir():
        raise ValueError(f'Diretório base dos projetos não existe ou não é um diretório: {base}')
    return [
        {'name': child.name, 'context': str(child.resolve()),
         'values_path': str(child.resolve() / 'values_tilt.yaml')}
        for child in sorted(base.iterdir())
        if not child.name.startswith('.') and child.is_dir()
    ]


if __name__ == '__main__':
    try:
        print(json.dumps(discover(sys.argv[1])))
    except (OSError, ValueError, IndexError) as exc:
        print(f'Erro na descoberta dos projetos: {exc}', file=sys.stderr)
        sys.exit(1)
