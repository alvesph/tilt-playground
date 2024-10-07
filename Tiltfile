load('ext://uibutton', 'cmd_button', 'text_input', 'location')
load("ext://dotenv", "dotenv")
dotenv()

cmd_button(
    'clean_docker',
    argv=['sh', '-c', 'chmod +x ./toolkit/clean_docker.sh && ./toolkit/clean_docker.sh'],
    location=location.NAV,
    icon_name='delete_sweep',
    text='Limpar Docker'
)

cmd_button(
    'excluded_cluster_k3d',
    argv=['sh', '-c', 'chmod +x ./toolkit/excluded_cluster_k3d.sh && ./toolkit/excluded_cluster_k3d.sh'],
    location=location.NAV,
    icon_name='build',
    text='Excluir Cluster'
)

#Toolkit
local_resource(
    'create-cluster',
    cmd='chmod +x toolkit/create_cluster.sh && toolkit/create_cluster.sh',
    labels=['toolkit']
)

local_resource(
    'use-context-dev',
    cmd='kubectl config use-context k3d-playground',
    labels=['toolkit'],
    deps=['create-cluster']
)

# PROJECTS
repo_base = os.getenv('REPO_BASE')
namespace = os.getenv('NAMESPACE_DEV')
npm_token = os.getenv('NPM_TOKEN')

def read_file(file_path):
    return local('cat {}'.format(file_path))

projects_content = read_file('./projects.json')
services_content = read_file('./services.json')

projects = decode_json(projects_content)
services = decode_json(services_content)

for project in projects:
    if project["active"] == 'true':
        if project["type"] == "node":
            # Build para projetos Node.js
            docker_build(
                repo_base + project["name"] + ':latest',
                project["path"] + project["name"],
                dockerfile= project["path"] + project["name"] + '/Dockerfile',
                target='develop',
                build_args={
                    'NPM_READ_TOKEN': npm_token
                },
                live_update=[
                    sync(project["path"] + project["name"], "/process"),
                    run('cd /process && npm install', trigger=[project["path"] + project["name"] + '/package.json'])
                ]
            )
        elif project["type"] == "go":
            # Build para projetos Go
            docker_build(
                repo_base + project["name"] + ':latest',
                project["path"] + project["name"],
                dockerfile=project["path"] + project["name"] + '/Dockerfile',
                live_update=[
                    sync(project["path"] + project["name"], "/app"),
                    run('cd /app && go build -o /app/' + project["name"], trigger=[project["path"] + project["name"] + '/main.go'])
                ]
            )

        # Helm e Kubernetes config para ambos os tipos de projeto
        yaml = helm(
            './services/playground-resource',
            name=project["name"] + '-pg',
            namespace=namespace,
            values=[project["path_value"] + project["name_application"] + '.yaml'],
            set=[],
        )
        k8s_yaml(yaml)
        k8s_resource(project["name_application"] + '-pg', labels=['Applications'])
        k8s_resource(project["name_application"] + '-pg', port_forwards=project["port"] + ':80')

# local_resource(
#     'helm_repo_add_datadog',
#     cmd='helm repo add datadog https://helm.datadoghq.com && helm repo update',
#     labels=['datadog']
# )

# # Instalando o Datadog Agent
# local_resource(
#     'install_datadog_agent',
#     cmd='helm install datadog-agent -f datadog-values.yaml datadog/datadog',
#     labels=['datadog'],
#     deps=['helm_repo_add_datadog']
# )

## SERVICES
for service in services:
    if service["active"] == 'true':
        local_resource(
            service["name"] + '-repo',
            cmd='helm repo add' + ' ' + service["name"] + ' ' + service["url"],
            labels=['helm']
        )

        local_resource(
            service["name"],
            cmd='helm upgrade --install' + ' ' + service["alias"] + ' ' + '-f' + ' ' + service["path_value"] + service["value_name"] + '.yaml' + ' ' + service["helm_repo"],
            labels=['helm'],
            deps=[service["name"] + '-repo']
        )