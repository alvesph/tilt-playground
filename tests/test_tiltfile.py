"""Avalia o Tiltfile real sem criar cluster, construir imagens ou instalar releases."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TiltfileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copy(ROOT / 'Tiltfile', self.root)
        shutil.copytree(ROOT / 'applications/playground-resource', self.root / 'applications/playground-resource')
        (self.root / 'toolkit').mkdir()
        shutil.copy(ROOT / 'toolkit/discover_projects.py', self.root / 'toolkit')
        (self.root / 'workspace/demo').mkdir(parents=True)
        self.app = self.root / 'workspace/demo'
        (self.app / 'Dockerfile').write_text('FROM busybox AS develop\nCMD ["sleep", "3600"]\n')
        (self.app / 'values_tilt.yaml').write_text('enabled: true\nservice:\n  targetPort: 9000\nconfigMap:\n  FROM_APP: yes\nreadinessProbe: null\nlivenessProbe: null\n')
        (self.root / 'service.yaml').write_text('{}\n')
        self.projects = {'path': './workspace'}
        self.services = []
        (self.root / 'kubeconfig').write_text('''apiVersion: v1
kind: Config
current-context: k3d-playground
clusters:
- name: playground
  cluster:
    server: https://127.0.0.1:6445
contexts:
- name: k3d-playground
  context:
    cluster: playground
    user: playground
users:
- name: playground
  user: {}
''')

    def service(self, name, depends_on=None):
        return {'name': 'example', 'alias': name, 'url': 'https://example.com/charts',
                'helm_repo': 'example/' + name, 'namespace': 'deps',
                'values': './service.yaml', 'depends_on': depends_on or []}

    def evaluate(self, error=None, resources=None):
        (self.root / 'projects.json').write_text(json.dumps(self.projects))
        (self.root / 'services.json').write_text(json.dumps(self.services))
        command = ['tilt', 'alpha', 'tiltfile-result', '--context', 'k3d-playground']
        if resources:
            command += ['--'] + resources
        proc = subprocess.run(command,
                              cwd=self.root, text=True, capture_output=True,
                              env={**os.environ, 'KUBECONFIG': str(self.root / 'kubeconfig')})
        if error:
            self.assertIn(error, proc.stdout + proc.stderr)
            return
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertFalse(result['Error'], result['Error'])
        return {m['Name']: m for m in result['Manifests']}

    def options(self, content):
        with (self.app / 'values_tilt.yaml').open('a') as f:
            f.write('tilt:\n' + content)

    def test_discovers_enabled_app_and_values(self):
        manifests = self.evaluate()
        self.assertEqual(set(manifests), {'demo-pg'})
        rendered = json.dumps(manifests['demo-pg'])
        self.assertIn('9000', rendered)
        self.assertIn('FROM_APP', rendered)

    def test_transitive_dependencies_and_shared_repo(self):
        self.options('  depends_on: [storage, queue]\n')
        self.services = [self.service('storage', ['queue']), self.service('queue')]
        manifests = self.evaluate()
        self.assertEqual(set(manifests), {'demo-pg', 'storage', 'queue', 'repo-example'})
        self.assertEqual(set(manifests['demo-pg']['ResourceDependencies']), {'storage', 'queue'})
        self.assertEqual(set(manifests['storage']['ResourceDependencies']), {'repo-example', 'queue'})
        self.assertIn('deleteCmd', manifests['storage']['DeployTarget'])

    def test_explicit_selection_replaces_service_defaults(self):
        self.services = [self.service('unused')]
        self.services[0]['active'] = True
        self.assertEqual(set(self.evaluate(resources=['demo'])), {'demo-pg'})

    def test_cycle_is_reported(self):
        self.options('  depends_on: [storage]\n')
        self.services = [self.service('storage', ['demo'])]
        self.evaluate('Ciclo de dependências')

    def test_unknown_dependency_is_reported(self):
        self.options('  depends_on: [missing]\n')
        self.evaluate('App/serviço desconhecido: missing')

    def test_disabled_app_needs_no_dockerfile(self):
        disabled = self.root / 'workspace/disabled'
        disabled.mkdir()
        (disabled / 'values_tilt.yaml').write_text('enabled: false\n')
        self.assertEqual(set(self.evaluate()), {'demo-pg'})

    def test_projects_without_values_are_ignored(self):
        (self.root / 'workspace/other').mkdir()
        (self.root / 'workspace/not-a-project.txt').write_text('test')
        self.assertEqual(set(self.evaluate()), {'demo-pg'})

    def test_missing_enabled_is_disabled(self):
        values = self.app / 'values_tilt.yaml'
        values.write_text(values.read_text().replace('enabled: true\n', ''))
        self.assertEqual(self.evaluate(), {})

    def test_string_enabled_is_rejected(self):
        values = self.app / 'values_tilt.yaml'
        values.write_text('enabled: "true"\n')
        self.evaluate('enabled deve ser booleano')

    def test_invalid_base_path(self):
        self.projects['path'] = './missing'
        self.evaluate('Diretório base dos projetos não existe')

    def test_base_path_must_be_directory(self):
        self.projects['path'] = './service.yaml'
        self.evaluate('não é um diretório')

    def test_scan_is_not_recursive(self):
        nested = self.root / 'workspace/other/nested'
        nested.mkdir(parents=True)
        (nested / 'values_tilt.yaml').write_text('enabled: true\n')
        self.assertEqual(set(self.evaluate()), {'demo-pg'})

    def test_optional_name_and_build_target(self):
        self.options('  name: demo-api\n  build:\n    target: custom\n')
        manifests = self.evaluate()
        self.assertEqual(set(manifests), {'demo-api-pg'})
        self.assertEqual(manifests['demo-api-pg']['ImageTargets'][0]['BuildDetails']['target'], 'custom')

    def test_explicit_selection_does_not_enable_disabled_app(self):
        values = self.app / 'values_tilt.yaml'
        values.write_text('enabled: false\n')
        self.evaluate('App/serviço desconhecido: demo', resources=['demo'])


if __name__ == '__main__':
    unittest.main()
