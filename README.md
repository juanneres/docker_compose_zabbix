# Ambiente Zabbix + Grafana com Docker

Stack completa de monitoramento pronta para subir com **um comando**:

- **Zabbix 7.4** (server, frontend web e agent)
- **PostgreSQL 16** como banco de dados
- **Grafana 12** já com o plugin do Zabbix instalado

Basta seguir os passos na ordem.

---

## Índice

1. [Pré-requisitos](#1-pré-requisitos)
   - [1.1. Instalar o Docker no Ubuntu Server (LTS)](#11-instalar-o-docker-no-ubuntu-server-lts)
2. [Baixar os arquivos](#2-baixar-os-arquivos)
3. [Configurar o arquivo `.env`](#3-configurar-o-arquivo-env)
4. [Subir o ambiente](#4-subir-o-ambiente)
5. [Verificar se está tudo no ar](#5-verificar-se-está-tudo-no-ar)
6. [Acessar o Zabbix Web](#6-acessar-o-zabbix-web)
7. [Acessar o Grafana](#7-acessar-o-grafana)
8. [Habilitar o plugin do Zabbix no Grafana](#8-habilitar-o-plugin-do-zabbix-no-grafana)
9. [Conectar o Grafana ao Zabbix (datasource)](#9-conectar-o-grafana-ao-zabbix-datasource)
10. [Comandos úteis do dia a dia](#10-comandos-úteis-do-dia-a-dia)
11. [Solução de problemas](#11-solução-de-problemas)

---

## 1. Pré-requisitos

Você precisa ter instalado na máquina:

- **Docker Engine** 20+
- **Docker Compose v2** (já vem junto do Docker moderno, como plugin)

Para conferir se já estão instalados, abra o terminal e rode:

```bash
docker --version
docker compose version
```

Se os dois comandos mostrarem uma versão, pule para o [passo 2](#2-baixar-os-arquivos).
Se der "command not found", instale o Docker seguindo a seção **1.1** abaixo (para
Ubuntu Server) ou o [guia oficial](https://docs.docker.com/engine/install/) para
outros sistemas.

### 1.1. Instalar o Docker no Ubuntu Server (LTS)

Passo a passo usando o **repositório oficial da Docker** (recomendado). Todos os
comandos são rodados via terminal/SSH no servidor.

**1. Atualizar o sistema:**

```bash
sudo apt update
sudo apt upgrade -y
```

**2. Instalar dependências necessárias:**

```bash
sudo apt install -y ca-certificates curl
```

**3. Adicionar a chave GPG oficial da Docker:**

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

**4. Adicionar o repositório oficial da Docker:**

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

**5. Atualizar a lista de pacotes** (agora incluindo o repositório da Docker):

```bash
sudo apt update
```

**6. Instalar o Docker Engine e o Docker Compose:**

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**7. Habilitar o Docker para iniciar junto com o sistema:**

```bash
sudo systemctl enable docker
sudo systemctl enable containerd
```

**8. Iniciar o serviço do Docker:**

```bash
sudo systemctl start docker
```

**9. Permitir rodar o Docker sem `sudo`** (adiciona seu usuário ao grupo `docker`):

```bash
sudo usermod -aG docker $USER
```

> Para liberar outro usuário, troque `$USER` pelo nome dele:
> `sudo usermod -aG docker nome_do_usuario`
>
> ⚠️ Usuários no grupo `docker` podem executar containers com privilégios
> elevados no sistema. Adicione apenas contas de confiança.

**10. Aplicar a mudança de grupo.** A forma mais garantida é encerrar a sessão SSH
e conectar de novo (`exit` e reconecte). Para aplicar na hora, sem deslogar:

```bash
newgrp docker
```

**11. Verificar se o Docker está ativo e funcionando:**

```bash
systemctl status docker
docker --version
docker compose version
```

Se o serviço aparecer como `active (running)` e os comandos de versão
responderem, o Docker está pronto. Siga para o [passo 2](#2-baixar-os-arquivos).

> 📋 **Todos os comandos de uma vez** (copie e cole em sequência):
>
> ```bash
> sudo apt update && sudo apt upgrade -y
> sudo apt install -y ca-certificates curl
> sudo install -m 0755 -d /etc/apt/keyrings
> sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
> sudo chmod a+r /etc/apt/keyrings/docker.asc
> echo \
>   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
>   $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
>   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
> sudo apt update
> sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
> sudo systemctl enable docker
> sudo systemctl enable containerd
> sudo systemctl start docker
> sudo usermod -aG docker $USER
> newgrp docker
> systemctl status docker
> docker --version
> docker compose version
> ```

> 💡 As **portas** abaixo precisam estar livres no seu computador:
> `8080` (Zabbix Web), `8443` (Zabbix Web HTTPS), `3000` (Grafana) e `10051`
> (Zabbix Server). Se alguma estiver ocupada, veja o [passo 3](#3-configurar-o-arquivo-env)
> para trocar.

---

## 2. Baixar os arquivos

Clone o repositório (ou baixe o ZIP) e entre na pasta:

```bash
git clone <URL-do-repositorio> docker_compose_zabbix
cd docker_compose_zabbix
```

Você deve ver estes arquivos principais:

```
docker-compose.yml   → descreve todos os serviços
.env.example         → modelo de configuração (você copia para .env)
init/                → script que cria o banco do Grafana
```

---

## 3. Configurar o arquivo `.env`

O arquivo `.env` guarda **todas as configurações** (senhas, portas, versões).
Ele **não** vem pronto — você cria a partir do modelo `.env.example`:

```bash
cp .env.example .env
```

Agora abra o `.env` num editor de texto. Os campos mais importantes:

```env
# --- Senhas do banco (troque em produção!) ---
POSTGRES_USER=zabbix
POSTGRES_PASSWORD=zabbix        # ⚠️ troque por uma senha forte
POSTGRES_DB=zabbix

# --- Portas que você acessa pelo navegador ---
ZBX_WEB_PORT=8080               # endereço do Zabbix: http://localhost:8080
GRAFANA_PORT=3000               # endereço do Grafana: http://localhost:3000

# --- Login inicial do Grafana ---
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin    # ⚠️ troque por uma senha forte
```

**Você não precisa mudar nada para apenas testar.** Os valores padrão já funcionam.

> ⚠️ **Importante:** se você for usar isto de verdade (não só teste), **troque as
> senhas** (`POSTGRES_PASSWORD` e `GRAFANA_ADMIN_PASSWORD`) antes de subir.
>
> 🔌 **Porta ocupada?** Se a porta `8080` já estiver em uso por outro programa,
> mude `ZBX_WEB_PORT` para outro valor livre, por exemplo `ZBX_WEB_PORT=8081`.
> Faça o mesmo com `GRAFANA_PORT` se a `3000` estiver ocupada.

---

## 4. Subir o ambiente

Com o `.env` pronto, rode **um único comando** na pasta do projeto:

```bash
docker compose up -d
```

O que acontece:

- Na **primeira vez**, o Docker baixa as imagens (pode levar alguns minutos,
  dependendo da internet).
- Nas próximas vezes, sobe em segundos.
- O `-d` faz tudo rodar em segundo plano (você recupera o terminal).

Quando terminar, você verá cada container com "Started".

---

## 5. Verificar se está tudo no ar

Rode:

```bash
docker compose ps
```

Você deve ver **5 containers** e todos com o status `healthy` (saudável):

```
NAME              STATUS
grafana           Up (healthy)
zabbix-agent      Up (healthy)
zabbix-postgres   Up (healthy)
zabbix-server     Up (healthy)
zabbix-web        Up (healthy)
```

> ⏳ Logo depois de subir, alguns podem aparecer como `health: starting`.
> Espere ~40 segundos e rode `docker compose ps` de novo até virarem `healthy`.

---

## 6. Acessar o Zabbix Web

Abra no navegador (troque a porta se você alterou `ZBX_WEB_PORT`):

👉 **http://localhost:8080**

Login inicial padrão do Zabbix:

| Campo   | Valor   |
| ------- | ------- |
| Usuário | `Admin` |
| Senha   | `zabbix` |

> ⚠️ Atenção às letras: o usuário é **`Admin`** com "A" maiúsculo.

**Assim que entrar, troque a senha:** clique no ícone de usuário (canto inferior
esquerdo) → **User settings** → **Change password**.

---

## 7. Acessar o Grafana

Abra no navegador (troque a porta se você alterou `GRAFANA_PORT`):

👉 **http://localhost:3000**

Login inicial (o que você definiu no `.env`, padrão):

| Campo   | Valor   |
| ------- | ------- |
| Usuário | `admin` |
| Senha   | `admin` |

Na primeira entrada o Grafana pede para **definir uma nova senha** — defina uma.

---

## 8. Habilitar o plugin do Zabbix no Grafana

O plugin já vem **instalado**, mas você precisa **ativá-lo** uma vez:

1. No menu lateral, vá em **Administration** → **Plugins and data** → **Plugins**.
2. No campo de busca, digite **Zabbix**.
3. Clique no resultado **Zabbix** (por Alexander Zobnin).
4. Clique no botão **Enable** (Ativar).

Pronto, o plugin está ativo. Agora falta ligar o Grafana ao Zabbix.

---

## 9. Conectar o Grafana ao Zabbix (datasource)

O "datasource" é a **ponte** que faz o Grafana ler os dados do Zabbix.

1. No menu lateral, vá em **Connections** → **Data sources**.
2. Clique em **Add data source**.
3. Busque e selecione **Zabbix**.
4. Preencha os campos:

   **Seção HTTP → campo URL** (⚠️ este é o passo que mais confunde):

   ```
   http://zabbix-web:8080/api_jsonrpc.php
   ```

   > 📌 Use exatamente esse endereço. **Não** use `localhost` aqui! Dentro do
   > Docker, o Grafana enxerga o Zabbix pelo nome do container (`zabbix-web`) e
   > pela porta **interna** `8080` — que é sempre 8080, mesmo que você tenha
   > mudado `ZBX_WEB_PORT` no `.env` (aquela porta é só para o seu navegador).

   **Seção Zabbix API details:**

   | Campo    | Valor                                   |
   | -------- | --------------------------------------- |
   | Username | `Admin` (ou um usuário dedicado — veja abaixo) |
   | Password | a senha do Zabbix                       |

   Deixe as demais opções (Trends, cache) nos valores padrão.

5. Clique em **Save & test** (Salvar e testar).

   Deve aparecer uma mensagem verde de sucesso, algo como
   **"Zabbix API version: 7.4.x"**. Se aparecer, está conectado! 🎉

> 🔐 **Boa prática (opcional, recomendado):** em vez de usar o `Admin` no
> datasource, crie no Zabbix um usuário só para o Grafana:
> **Users → Users → Create user**, com papel de leitura (por ex. função
> "Guest role" ou um role de somente leitura) e use esse login/senha no passo 4.
> Assim o Grafana não precisa da conta de administrador.

### Ver os dados

Com o datasource conectado, crie um dashboard:

1. Menu lateral → **Dashboards** → **New** → **New dashboard** → **Add visualization**.
2. Escolha o datasource **Zabbix**.
3. Selecione **Group**, **Host** e **Item** que quer visualizar.

Ou importe dashboards prontos da comunidade: **Dashboards → New → Import** e use
um ID do site [grafana.com/dashboards](https://grafana.com/grafana/dashboards/)
(busque por "Zabbix").

---

## 10. Comandos úteis do dia a dia

Todos são rodados **dentro da pasta do projeto**:

| Ação                                        | Comando                          |
| ------------------------------------------- | -------------------------------- |
| Subir o ambiente                            | `docker compose up -d`           |
| Ver o status dos containers                 | `docker compose ps`              |
| Ver os logs (todos)                         | `docker compose logs -f`         |
| Ver o log de um serviço                     | `docker compose logs -f zabbix-server` |
| Parar (sem apagar dados)                    | `docker compose stop`            |
| Ligar de novo depois de parar               | `docker compose start`           |
| Derrubar os containers (mantém os dados)    | `docker compose down`            |
| Derrubar **e apagar TODOS os dados**        | `docker compose down -v`         |

> 💾 Os dados (banco, configurações do Grafana, dashboards) ficam guardados em
> **volumes** do Docker. Um `docker compose down` normal **não apaga** nada — você
> pode subir de novo depois e tudo estará lá. Só o `down -v` apaga tudo.

---

## 11. Solução de problemas

**"address already in use" / "port is already allocated"**
Alguma porta já está sendo usada. Edite o `.env` e troque `ZBX_WEB_PORT` e/ou
`GRAFANA_PORT` para valores livres, depois rode `docker compose up -d` de novo.

**Um container fica reiniciando ou como `unhealthy`**
Veja o log dele para entender o motivo:
```bash
docker compose logs -f <nome-do-container>
```
(ex.: `docker compose logs -f zabbix-server`)

**O Grafana não conecta no Zabbix ("Save & test" falha)**
- Confirme que a URL é `http://zabbix-web:8080/api_jsonrpc.php` (nome do container
  + porta **8080** interna, **não** `localhost`).
- Confirme usuário/senha do Zabbix.
- Confirme que o container `zabbix-web` está `healthy` (`docker compose ps`).

**Esqueci a senha do Grafana**
Você pode redefinir por dentro do container:
```bash
docker exec -it grafana grafana cli admin reset-admin-password NOVA_SENHA
```

**Quero começar do zero (apagar tudo)**
```bash
docker compose down -v
docker compose up -d
```
⚠️ Isso apaga **todos os dados** (hosts, dashboards, histórico).
