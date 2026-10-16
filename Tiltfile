# O cluster deve existir antes de iniciar o Tilt: bash toolkit/playground.sh up
load('ext://helm_resource', 'helm_resource', 'helm_repo')

allow_k8s_contexts('k3d-playground')
if k8s_context() != 'k3d-playground':
    fail('Use o contexto k3d-playground: bash toolkit/playground.sh up')
config.define_string_list('resources', args=True)
cfg = config.parse()
requested = cfg.get('resources', [])

CHART = './applications/playground-resource'
REGISTRY = 'k3d-registry.localhost:5006/'


def enabled(item):
    return item.get('active', False) in [True, 'true']


# Lista só o primeiro nível. Não percorre node_modules, .git ou fontes dos apps.
watch_file('toolkit/discover_projects.py')
watch_file('projects.json')
projects = decode_json(local(['python3', 'toolkit/discover_projects.py', 'projects.json'], quiet=True))
services = decode_json(read_file('services.json'))
catalog = {}
defaults = []
for project in projects:
    values_path = project['values_path']
    # Também observa o caminho ainda inexistente: criar/remover o arquivo recarrega.
    watch_file(values_path)
    if not os.path.exists(values_path):
        continue
    values = decode_yaml(read_file(values_path))
    if type(values) != 'dict':
        fail('O arquivo de values deve ser um mapa YAML: ' + values_path)
    app_enabled = values.get('enabled', False)
    if type(app_enabled) != 'bool':
        fail('enabled deve ser booleano true/false: ' + values_path)
    if not app_enabled:
        continue
    options = values.get('tilt', {})
    if type(options) != 'dict':
        fail('tilt deve ser um mapa YAML: ' + values_path)
    name = options.get('name', project['name'])
    if name in catalog:
        fail('Nome duplicado: ' + name)
    catalog[name] = {
        'kind': 'app', 'spec': {},
        'context': project['context'], 'values_path': values_path,
        'values': values, 'options': options,
    }
    defaults.append(name)
for service in services:
    name = service['alias']
    if name in catalog:
        fail('Nome duplicado: ' + name)
    catalog[name] = {'kind': 'service', 'spec': service}
    if enabled(service):
        defaults.append(name)

# Expansão iterativa: inclui dependências transitivas sem recursão.
selected = list({name: True for name in (requested if requested else defaults)}.keys())
resolved = {}
for unused in range(len(catalog) + 1):
    pending = [name for name in selected if name not in resolved]
    if not pending:
        break
    for name in pending:
        if name not in catalog:
            fail('App/serviço desconhecido: ' + name + '. Confira enabled no values_tilt.yaml e services.json.')
        entry = dict(catalog[name])
        spec = entry['spec']
        if entry['kind'] == 'app':
            dependencies = entry['options'].get('depends_on', [])
        else:
            version = spec.get('version', '')
            if type(version) != 'string' or len(version.split('.')) != 3 or not all([part.isdigit() for part in version.split('.')]):
                fail('Defina version com a versão exata do chart (ex.: 1.2.3) para o serviço: ' + name)
            dependencies = spec.get('depends_on', [])
        if type(dependencies) != 'list':
            fail('depends_on deve ser uma lista: ' + name)
        entry['dependencies'] = dependencies
        resolved[name] = entry
        for dependency in dependencies:
            if dependency not in selected:
                selected.append(dependency)

# Valida ciclos e define a ordem antes de registrar builds ou instalações.
ordered = []
for unused in range(len(resolved)):
    ready = [name for name in selected if name not in ordered and all([dep in ordered for dep in resolved[name]['dependencies']])]
    ordered.extend(ready)
if len(ordered) != len(resolved):
    fail('Ciclo de dependências entre: ' + ', '.join([name for name in selected if name not in ordered]))

repos = {}
for name in ordered:
    entry = resolved[name]
    spec = entry['spec']
    if entry['kind'] == 'service':
        repo = spec['name']
        if repo not in repos:
            helm_repo(repo, spec['url'], resource_name='repo-' + repo, labels=['repositories'])
            repos[repo] = spec['url']
        elif repos[repo] != spec['url']:
            fail('URLs conflitantes para o repositório: ' + repo)
        values_path = spec.get('values', './services/values_service/' + spec.get('value_name', 'values-' + name) + '.yaml')
        if not os.path.exists(values_path):
            fail('Values do serviço ' + name + ' não encontrado: ' + values_path)
        flags = ['--create-namespace', '--values', values_path, '--version', spec['version']]
        helm_resource(
            name, spec['helm_repo'], namespace=spec['namespace'],
            flags=flags, deps=[values_path],
            resource_deps=['repo-' + repo] + [dep + '-pg' if resolved[dep]['kind'] == 'app' else dep for dep in entry['dependencies']],
            pod_readiness='wait', labels=['Services'],
            port_forwards=spec.get('port_forwards', []),
        )
    else:
        context = entry['context']
        options = entry['options']
        build = options.get('build', {})
        dockerfile = build.get('dockerfile', 'Dockerfile')
        dockerfile = os.path.join(context, dockerfile)
        if not os.path.exists(dockerfile):
            fail('Dockerfile do app ' + name + ' não encontrado: ' + dockerfile)
        target = build.get('target', 'develop')
        build_args = dict(build.get('args', {}))
        image = REGISTRY + name
        # Rebuild por padrão: funciona sem presumir linguagem, diretórios ou watcher.
        docker_build(image, context, dockerfile=dockerfile, target=target, build_args=build_args)
        set_values = ['fullnameOverride=' + name + '-pg', 'image.repository=' + image, 'image.tag=latest']
        service_values = entry['values'].get('service', {})
        remote_port = int(service_values.get('targetPort', 8080))
        set_values.append('service.targetPort=' + str(remote_port))
        k8s_yaml(helm(CHART, name=name + '-pg', namespace='default', values=[entry['values_path']], set=set_values))
        k8s_resource(
            name + '-pg', labels=['Applications'],
            objects=[name + '-pg:configmap', name + '-pg:secret'],
            resource_deps=[dep + '-pg' if resolved[dep]['kind'] == 'app' else dep for dep in entry['dependencies']],
            port_forwards=[str(options.get('local_port', remote_port)) + ':' + str(remote_port)],
        )

if not selected:
    print('Nenhum recurso selecionado. Habilite enabled: true no values_tilt.yaml de um app.')
