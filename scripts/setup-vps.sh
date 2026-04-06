#!/usr/bin/env bash
#
# Настройка свежего Ubuntu-сервера.
# Запускается ЛОКАЛЬНО — подключается к серверу по SSH как root.
#
# Использование:
#   ./scripts/setup-vps.sh <IP> <SSH_KEY> [USERNAME]
#
# Аргументы:
#   IP        — адрес сервера
#   SSH_KEY   — путь к публичному SSH-ключу (~/.ssh/id_ed25519.pub)
#   USERNAME  — имя пользователя (по умолчанию: deploy)
#
# Пример:
#   ./scripts/setup-vps.sh 203.0.113.10 ~/.ssh/id_ed25519.pub deploy

set -euo pipefail

# ─── Аргументы ───────────────────────────────────────────────

SERVER_IP="${1:-}"
SSH_KEY_PATH="${2:-}"
USERNAME="${3:-deploy}"

if [[ -z "$SERVER_IP" || -z "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: не указаны обязательные аргументы."
  echo "Использование: $0 <IP> <SSH_KEY> [USERNAME]"
  exit 1
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "Ошибка: файл SSH-ключа не найден: $SSH_KEY_PATH"
  exit 1
fi

SSH_KEY=$(cat "$SSH_KEY_PATH")
# accept-new: автоматически принимает host key при первом подключении
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)

echo "═══════════════════════════════════════════════"
echo " Настройка сервера $SERVER_IP"
echo " Пользователь: $USERNAME"
echo " SSH-ключ:     $SSH_KEY_PATH"
echo "═══════════════════════════════════════════════"
echo

# ─── Вспомогательная функция для выполнения команд на сервере ─

remote() {
  ssh "${SSH_OPTS[@]}" "root@$SERVER_IP" "$@"
}

# ─── 1. Обновление системы ───────────────────────────────────

echo "▸ [1/5] Обновление системы..."

remote "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get upgrade -y -qq
" && echo "  ✓ Система обновлена." \
  || { echo "  ✗ Ошибка при обновлении системы."; exit 1; }

echo

# ─── 2. Настройка firewall ───────────────────────────────────

echo "▸ [2/5] Настройка firewall (UFW)..."

remote "
  apt-get install -y -qq ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  echo 'y' | ufw enable
  ufw status
" && echo "  ✓ Firewall настроен: открыты порты 22, 80, 443." \
  || { echo "  ✗ Ошибка при настройке firewall."; exit 1; }

echo

# ─── 3. Создание пользователя ────────────────────────────────

echo "▸ [3/5] Создание пользователя $USERNAME..."

remote "
  if id '$USERNAME' &>/dev/null; then
    echo '  Пользователь $USERNAME уже существует — пропускаю.'
  else
    adduser --disabled-password --gecos '' '$USERNAME'
    usermod -aG sudo '$USERNAME'
    echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$USERNAME
    chmod 440 /etc/sudoers.d/$USERNAME
    echo '  Пользователь создан и добавлен в sudo.'
  fi

  mkdir -p /home/$USERNAME/.ssh
  grep -qxF '$SSH_KEY' /home/$USERNAME/.ssh/authorized_keys 2>/dev/null \
    || echo '$SSH_KEY' >> /home/$USERNAME/.ssh/authorized_keys
  chmod 700 /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
" && echo "  ✓ Пользователь $USERNAME готов, SSH-ключ установлен." \
  || { echo "  ✗ Ошибка при создании пользователя."; exit 1; }

echo

# ─── 4. Установка Docker ────────────────────────────────────

echo "▸ [4/5] Установка Docker..."

ssh "${SSH_OPTS[@]}" "root@$SERVER_IP" bash -s "$USERNAME" <<'DOCKER_EOF'
  set -euo pipefail
  DEPLOY_USER="$1"

  if command -v docker &>/dev/null; then
    echo '  Docker уже установлен — пропускаю.'
  else
    apt-get install -y -qq ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) \
      signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
  fi

  usermod -aG docker "$DEPLOY_USER"
DOCKER_EOF
test $? -eq 0 && echo "  ✓ Docker установлен, $USERNAME добавлен в группу docker." \
  || { echo "  ✗ Ошибка при установке Docker."; exit 1; }

echo

# ─── 5. Отключение входа по паролю ──────────────────────────

echo "▸ [5/5] Отключение входа по паролю..."
echo "  Проверяю SSH-доступ для $USERNAME..."

if ssh "${SSH_OPTS[@]}" "$USERNAME@$SERVER_IP" "echo ok" &>/dev/null; then
  echo "  ✓ SSH-ключ работает для $USERNAME."

  remote "
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl reload sshd
  " && echo "  ✓ Вход по паролю отключён, root-логин запрещён." \
    || { echo "  ✗ Ошибка при настройке SSH."; exit 1; }
else
  echo "  ✗ SSH-ключ НЕ работает для $USERNAME — вход по паролю НЕ отключён."
  echo "    Проверьте ключ и повторите вручную."
  exit 1
fi

echo
echo "═══════════════════════════════════════════════"
echo " Готово! Сервер $SERVER_IP настроен."
echo " Подключение: ssh $USERNAME@$SERVER_IP"
echo "═══════════════════════════════════════════════"
