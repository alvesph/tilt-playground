# Playground Kubernetes

Ambiente local para desenvolver apps com Docker, k3d, Tilt e um chart Helm compartilhado.
Cada app mantém seu `values_tilt.yaml`; o playground descobre os apps habilitados
em um diretório base e provisiona seus serviços.

## Requisitos

Docker acessível pelo usuário, k3d, kubectl, Helm 3, Tilt e Python 3.
O playbook `toolkit/install_dependencies.yml` é legado: confira a distribuição e os
repositórios antes de utilizá-lo. O fluxo abaixo não depende de Ansible.

## Diretório dos projetos

Configure uma única vez o `projects.json`:

```json
{
  "path": "/home/ph/projects"
}
```

O caminho deve existir e ser um diretório. Também aceita `~` ou um caminho relativo
a este playground. A lista antiga de apps foi substituída por esse objeto.
Não é mais necessário cadastrar cada projeto no JSON.

A descoberta examina apenas as subpastas diretas, sem percorrer `node_modules`,
`.git` ou projetos aninhados:

```text
/home/ph/projects/
├── meu-app/
│   ├── Dockerfile
│   └── values_tilt.yaml     # enabled: true → provisiona
├── outro-app/
│   └── values_tilt.yaml     # enabled: false → ignora
└── projeto-sem-values/     # ignora
```

## Habilitar um app

Copie `examples/values_tilt.yaml` para a raiz do projeto e adapte:

```yaml
enabled: true

tilt:
  build:
    dockerfile: Dockerfile
    target: develop
    args: {}
  local_port: 8080
  depends_on: [minio]

service:
  targetPort: 8080

configMap:
  REST_PORT: "8080"

readinessProbe:
  httpGet: null
  tcpSocket:
    port: http
livenessProbe: null
```

`enabled` fica na raiz do YAML e deve ser booleano: `true` ou `false`, sem aspas.
Quando ausente, o app é considerado desabilitado. Apps desabilitados não precisam
ter Dockerfile e não podem ser ativados por seleção explícita ou como dependência.

O nome padrão do app é o nome da pasta. Para personalizar, use `tilt.name: meu-app-api`.
Todas as configurações do app ficam nesse arquivo; o `projects.json` guarda apenas
o diretório base. A seção `tilt` e o campo `enabled` são lidos pelo playground;
os demais campos alimentam o chart compartilhado em `applications/playground-resource`.
O Helm combina os defaults do chart com os values do app. A imagem e o nome final
dos recursos são definidos pelo Tilt.

O Dockerfile deve conter o stage configurado (padrão: `develop`); use `target: ""`
para construir o stage final. O processo deve escutar em `0.0.0.0` na porta indicada.
A porta local pode ser diferente da porta do container, permitindo testar apps
com a mesma porta interna. O nome do recurso no painel e do Service é `meu-app-pg`.

## Rodar

```bash
# Valida o diretório base, cria/inicia o cluster e sobe os apps habilitados.
bash toolkit/playground.sh up

# Opcional: seleciona um subconjunto dos apps habilitados ou serviços.
bash toolkit/playground.sh up meu-app
```

O cluster é preparado antes do Tilt. O script espera os nós ficarem prontos e usa
explicitamente `k3d-playground`. O Tiltfile rejeita outros contextos.
Com o cluster já disponível: `tilt up --context k3d-playground`.
A seleção explícita substitui a seleção padrão, incluindo dependências transitivas.
Cada dependência compartilhada é registrada uma única vez.

Alterar um `values_tilt.yaml` observado recarrega o Tiltfile, incluindo mudanças em
`enabled`. Criar o arquivo numa pasta já descoberta também é observado. Se criar
uma pasta de projeto nova com o Tilt aberto, reinicie a sessão para descobri-la.
Isso evita observar recursivamente todo o diretório base de projetos.

## Serviços e dependências

`services.json` é o catálogo de infraestrutura. Exemplo de estrutura (preencha a
versão com uma versão real do chart escolhido):

```json
{
  "active": false,
  "name": "bitnami",
  "alias": "minio",
  "url": "https://charts.bitnami.com/bitnami",
  "helm_repo": "bitnami/minio",
  "namespace": "aws",
  "values": "./services/values_service/values-minio.yaml",
  "version": "VERSAO_DO_CHART",
  "depends_on": [],
  "port_forwards": ["9000:9000"]
}
```

Também é aceito o campo antigo `value_name` em vez de `values`.
`version` é opcional para compatibilidade; fixe uma versão válida para obter
reprodutibilidade. Os charts e imagens Bitnami existentes precisam ser revisados
antes do primeiro deploy, devido às mudanças de catálogo desde 2025.

Se o app declara `depends_on: [minio]`, o Tilt inclui o MinIO mesmo com
`active: false`. Serviços também podem declarar dependências. Nomes desconhecidos
e ciclos são rejeitados. Repositórios Helm compartilhados são registrados uma vez.

O provisionamento usa `helm_resource`: Tilt instala a release, acompanha os pods
e aguarda sua disponibilidade antes de iniciar os recursos dependentes.
Isso ordena a primeira inicialização; o app ainda deve tratar indisponibilidade
e reconectar durante a execução. Credenciais, buckets e conexões não são criados
ou injetados automaticamente: configure-os nos values de cada serviço e app.
Confirme os nomes dos Services dos charts para montar os endpoints DNS.

Os arquivos de values de serviços existentes continuam ignorados pelo Git;
configure-os localmente e versione apenas configurações sem credenciais.
O `.env` antigo não é lido pelo Tiltfile. Não coloque tokens reais no catálogo.
O campo `active` dos serviços permite subir infraestrutura independente dos apps;
aceita booleanos e as strings antigas `"true"`/`"false"`. Para subir serviços apenas
quando forem dependências, deixe `active: false` em suas entradas.
O MinIO permanece ativo no catálogo existente; desative-o se quiser esse comportamento.

## Encerrar

Após Ctrl+C no Tilt, use a mesma seleção utilizada na subida:

```bash
# Remove os apps selecionados e suas dependências, incluindo releases Helm.
bash toolkit/playground.sh down meu-app

# Para o cluster, preservando os recursos e dados existentes.
bash toolkit/playground.sh stop

# Apaga o cluster e seus dados locais (ação destrutiva).
k3d cluster delete playground
```

Dependências compartilhadas entram na remoção. Se outros apps ainda estiverem
usando o mesmo serviço, não execute `down` apenas para pausar um app: pare a sessão
ou ajuste a seleção com cuidado. PVCs podem permanecer após a remoção de releases,
conforme o chart. Recursos criados pelos antigos comandos Helm continuam sujeitos
à configuração e às credenciais da release original.

## Escopo e desenvolvimento

O chart compartilhado cobre apps executados como Deployment com uma porta,
Service, configurações, secrets, probes, recursos, ingress e volumes. Workers podem
usar `command`/`args`, mas Jobs, CronJobs e bancos com necessidades próprias exigem
outros templates/charts. Serviços de infraestrutura usam seus charts específicos.

Por padrão, alterações no código geram rebuild e redeploy. Isso funciona para
qualquer linguagem e substitui o antigo Live Update que presumia `/app`, `/process`
e reinício externo. Live Update pode ser acrescentado depois conforme cada runtime.
ConfigMaps e Secrets são agrupados com o app e disparam rollout quando mudam.
Probes agora são renderizadas: configure rotas reais ou desative com `null`.

O cluster está configurado com um servidor e `agents: 0`, para reduzir o consumo
local. O servidor também executa os apps. Alterar esse arquivo não redimensiona
um cluster já criado; a nova configuração vale na próxima criação do cluster.

## Verificações locais

```bash
helm lint applications/playground-resource
bash -n toolkit/playground.sh
python3 -m unittest discover -s tests -v
```

Os testes avaliam o Tiltfile real com kubeconfig temporário, sem subir Kubernetes,
construir imagens ou instalar releases. O primeiro uso da extensão `helm_resource`
pode exigir acesso à internet. Deploy e conectividade precisam ser validados no cluster.
