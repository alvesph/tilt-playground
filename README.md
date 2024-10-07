# Playground
Ambiente para testes

# Índice
* [Requisitos](#Requisitos)
* [Estrutura do Projeto](#Estrutura-do-projeto)
* [Descrição da Estrutura](#Descricao-da-Estrutura)
* [Comandos para Rodar](#Comandos-para-Rodar)
* [Dockerfile do Projeto](#Dockerfile-do-Projeto)
* [Permissão de usuário ao Docker](#Permissão-de-usuário-ao-Docker)

# Requisitos
- [Ansibl](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-extra-python-dependencies)
- [Docker](https://www.docker.com/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm]()
- [Tilt](https://docs.tilt.dev/install.html#linux)

# Intalando requisitos pelo Ansible

## Ansible
~~~bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
~~~

## Rodar o Ansible
~~~bash
# Dependencias que serão instaladas
# tilt, k3d, helm
ansible-playbook -i ./toolkit/hosts.ini ./toolkit/install_dependencies.yml --ask-become-pass
# Caso queira pular algum instalador, caso já tenha no sistema.
ansible-playbook -i ./toolkit/hosts.ini ./toolkit/install_dependencies.yml --ask-become-pass --skip-tags "docker"
~~~

## Observações
Antes de executar o tilt up, faça o seguinte:
- O docker precisa ter premissão para rodar em modo de usuário

# Estrutura do Projeto
```plaintext
/
├── projects
│   ├── sdk
│   ├── api
│   ├── ...
├── services
│   ├── playground-resource
│   ├── values
│       ├── sdk.yaml
│       ├── api.yaml
│       ├── ...
├── toolkit
│   ├── clean_docker.sh
│   ├── cluster.yaml
│   ├── create_cluster.yaml
│   ├── excluded_cluster_k3d.yaml
│   ├── hosts.ini
│   ├── install_dependencies.yaml
├── .env
├── .gitignore
├── projects.json
├── README.md
├── Tiltfile
```

# Descrição da Estrutura
- `projects`      - Onde serão inseridos os projetos para o teste. [Deve ser mantido o nome original dos projetos].
- `services`      - Recursos do kubernetes.
- `values`        - values.yaml dos projetos. [Deve ser mantido o nome original dos projetos].
- `toolkit`       - Ferramentas necessárias para rodar o prjeto.
- `.env`          - As envs do projeto tilt. 
- `projects.json` - Parâmetros para rodar o projeto. 
- `Tiltfile`      - Core do tilt.

## Uso do .env
- Modifique o nome .env.exemple para .env
~~~bash
REPO_BASE= # onde vai ficar o registry do projeto (procure o time de DevOps)
NAMESPACE_DEV=default # por padrão será usado o default, caso precise mudar, precisar falar com o time de DevOps
~~~

# Comandos para Rodar
- Para subir o ambiente
~~~bash
tilt up
# click no espaço
~~~
- Para derrubar o ambiente [DEVE SER FEITO SEMPRE QUE TERMINAR O TESTE]
~~~bash
# ctrl c
tilt down
~~~

# Dockerfile do Projeto
É necessário que o dockerfile tenha um stage `develop`
ex:
~~~dockerfile
FROM <IMAGE> AS develop
~~~

# Permissão de usuário ao Docker
Crie um grupo para adicionar o docker

```
sudo groupadd docker
sudo usermod -aG docker $USER

sudo chmod 660 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock
```
Após isso, reinicie o sistema 
```
sudo reboot
```
