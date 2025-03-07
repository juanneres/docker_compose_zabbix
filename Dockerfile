FROM zabbix/zabbix-server-mysql:latest

# Use o usuário root para instalar os pacotes
USER root

# Atualiza os repositórios e instala as dependências necessárias:
# - curl e jq para o script
# - coreutils para ter o GNU date (disponível como gdate)
RUN apk update && apk add --no-cache curl jq coreutils

# Retorna ao usuário padrão (geralmente "zabbix")
USER zabbix
