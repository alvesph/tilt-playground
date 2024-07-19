# load("ext://docker_build_sub", "docker_build_sub")
# image_tag_blob = local('python3 toolkit/generate_uuid.py')
# image_tag = str(image_tag_blob).strip() 
load('ext://uibutton', 'cmd_button', 'text_input', 'location')
load("ext://dotenv", "dotenv")
dotenv()

cmd_button('hello',
          argv=['sh', '-c', 'echo Hello, $NAME'],
          location=location.NAV,
          icon_name='front_hand',
          text='Hello!',
          inputs=[
            text_input('NAME'),
          ],
)

# AUTHENTICATION AWS AND ECR
# local('chmod +x ./toolkit/authentication.sh')

# default_registry(
#   os.getenv('REPO_BASE')
# )


# local_resource(
#     name='create-regcred',
#     cmd='kubectl create secret generic regcred --from-file=.dockerconfigjson=$HOME/.docker/config.json --type=kubernetes.io/dockerconfigjson',
#     deps=['$HOME/.docker/config.json']
# )

# k8s_yaml('./toolkit/serviceaccount.yaml')

# CLUSTER
local_resource(
    'use-context-dev',
    cmd='kubectl config use-context k3d-somename',
    deps=['create-cluster'],
    labels=['user-cluster']
)

# PROJECTS
repo_base = os.getenv('REPO_BASE')
namespace = os.getenv('NAMESPACE_DEV')

if os.getenv('DEPLOY_WORKER_EXECUTOR') == 'true':
  docker_build(
      repo_base + 'latest',
      'projects/worker-executor-highcode/',
      dockerfile='./projects/worker-executor-highcode/Dockerfile',
      live_update=[
          sync("./projects/worker-executor-highcode/", "/process")
      ]
  )

  yaml = helm(
    './services/playground-resource',
    name='worker-executor-highcode-pg',
    namespace=namespace,
    values=['./services/values/worker-executor-highcode.yaml'],
    set=[],
    )
  k8s_yaml(yaml)
  k8s_resource('worker-executor-highcode-pg', labels=['Applications'])
  # k8s_resource('worker-executor-highcode-pg', port_forwards=80)