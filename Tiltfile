load('ext://uibutton', 'cmd_button', 'text_input', 'location')

cmd_button(
    'clean_docker',
    argv=['sh', '-c', 'chmod +x ./toolkit/manage_inseption.sh && ./toolkit/manage_inseption.sh clean_docker'],
    location=location.NAV,
    icon_name='delete_sweep',
    text='Limpar Docker'
)

cmd_button(
    'excluded_cluster_k3d',
    argv=['sh', '-c', 'chmod +x ./toolkit/manage_inseption.sh && ./toolkit/manage_inseption.sh exclude_cluster'],
    location=location.NAV,
    icon_name='build',
    text='Excluir Cluster'
)

local_resource(
    'create-cluster',
    cmd='chmod +x toolkit/manage_inseption.sh && toolkit/manage_inseption.sh create_cluster',
    labels=['toolkit']
)

local_resource(
    'use-context-dev',
    cmd='kubectl config use-context k3d-playground',
    labels=['toolkit'],
    deps=['create-cluster']
)

REPO_BASE = "k3d-registry.localhost:5006/"
NAMESPACE = "default"
NPM_TOKEN = ""
PATH_APP  = "./applications/"
PATH_APP_HELM_VALUES = "./applications/values_service/"
PATH_SERVICE_HELM_VALUES = "./services/values_service/"

def read_file(file_path):
    return local('cat {}'.format(file_path))

projects_content = read_file('./projects.json')
services_content = read_file('./services.json')

projects = decode_json(projects_content)
services = decode_json(services_content)

# PROJECTS
for project in projects:
    if project["active"] == 'true':
        if project["type"] == "node":
            # Build para projetos Node.js
            docker_build(
                REPO_BASE + project["name"] + ':latest',
                PATH_APP + project["name"],
                dockerfile= PATH_APP + project["name"] + '/Dockerfile',
                target='develop',
                build_args={
                    'NPM_READ_TOKEN': project["npm_token"]
                },
                live_update=[
                    sync(PATH_APP + project["name"], "/process"),
                    run('cd /process && npm install', trigger=[PATH_APP + project["name"] + '/package.json'])
                ]
            )
        elif project["type"] == "go":
            # Build para projetos Go
            docker_build(
                REPO_BASE + project["name"] + ':latest',
                PATH_APP + project["name"],
                dockerfile=PATH_APP + project["name"] + '/Dockerfile',
                live_update=[
                    sync(PATH_APP + project["name"], "/app"),
                    run('cd /app && go build -o /app/' + project["name"], trigger=[PATH_APP + project["name"] + '/main.go'])
                ]
            )

        # Helm e Kubernetes config para ambos os tipos de projeto
        yaml = helm(
            PATH_APP + 'playground-resource',
            name=project["name"] + '-pg',
            namespace=NAMESPACE,
            values=[PATH_APP + 'playground-resource/values.yaml'],
            set=['image.repository=' + REPO_BASE + project["name"]],
        )
        k8s_yaml(yaml)
        k8s_resource(project["name"] + '-pg', labels=['Applications'])
        k8s_resource(project["name"] + '-pg', port_forwards=str(project["port"]) + ':' + str(project["port"]))


## SERVICES
for service in services:
    if service["active"] == 'true':
        local_resource(
            service["name"] + '-repo',
            cmd='helm repo add' + ' ' + service["name"] + ' ' + service["url"],
            labels=['helm-repo']
        )

        local_resource(
            service["alias"],
            cmd='helm upgrade --install' + ' ' + service["alias"] + ' ' + '-f' + ' ' + PATH_SERVICE_HELM_VALUES + service["value_name"] + '.yaml' + ' ' + service["helm_repo"] + ' ' + '--namespace ' + service["namespace"] + ' ' + '--create-namespace',
            labels=['helm-charts'],
            deps=[service["name"] + '-repo']
        )
        
        local_resource(
            service["name"] + '-release',
            cmd='helm uninstall' + ' ' + service["alias"] + ' ' +  '-n' + ' ' + service["namespace"],
            labels=['helm-uninstall'],
            auto_init=False
        )
