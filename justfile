#!/usr/bin/just --justfile

set dotenv-path:=".env"
version:="1.11.0-beta.24"

install:
  just install_cert
  set dotenv-required
  just install_config
  just install_service
  just port_hopping
  just optimize

install_singbox:
  mkdir -p sing-box-install-tmp
  wget https://github.com/SagerNet/sing-box/releases/download/v{{version}}/sing-box-{{version}}-linux-amd64.tar.gz
  tar -xzf sing-box-{{version}}-linux-amd64.tar.gz
  install -Dm755 ./sing-box-{{version}}-linux-amd64/sing-box /usr/bin
  rm -rf sing-box-*

install_cert:
  mkdir -p /etc/hysteria \
    && openssl ecparam -genkey -name prime256v1 \
    -out /etc/hysteria/private.key \
    && openssl req -new -x509 -days 3650 -key /etc/hysteria/private.key \
    -out /etc/hysteria/cert.pem -subj "/CN=bing.com"

install_config:
  #!/usr/bin/bash
  mkdir -p /etc/sing-box
  cat > /etc/sing-box/config.json <<EOF
  {
    "inbounds": [
      {
        "type": "hysteria2",
        "listen": "::",
        "listen_port": $hysteria2_listen_port,
        "users": [
          {
            "name": "$user_name",
            "password": "$password"
          }
        ],
        "masquerade": "https://bing.com",
        "tls": {
          "enabled": true,
          "certificate_path": "/etc/hysteria/cert.pem",
          "key_path": "/etc/hysteria/private.key",
          "alpn": [
            "h3"
          ]
        }
      },
      {
        "type": "vless",
        "listen": "::",
        "listen_port": $reality_listen_port,
        "users": [
            {
                "uuid": "$uuid",
                "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
          "enabled": true,
          "server_name": "www.tesla.com",
          "reality": {
            "enabled": true,
            "handshake": {
                "server": "www.tesla.com",
                "server_port": 443,
            },
            "private_key": "$private_key",
            "short_id": [
              "$short_id"
            ]
          }
        }
      }
    ],
    "outbounds": [
      {
        "type": "direct"
      }
    ]
  }
  EOF

generate_reality_keypair:
  @sing-box generate reality-keypair

generate_uuid:
  @sing-box generate uuid

generate_short_id:
  @sing-box generate rand 8 --hex

generate_user_name:
  @sing-box generate rand 8 --base64

generate_password:
  @sing-box generate rand 32 --base64

generate_manual:
  just generate_reality_keypair
  just generate_uuid
  just generate_short_id

generate:
  #!/usr/bin/bash
  server_ip=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
  user_name=$(just generate_user_name)
  password=$(just generate_password)
  keypair=$(just generate_reality_keypair)
  private_key=$(echo $keypair | awk '{print $2}')
  public_key=$(echo $keypair | awk '{print $4}')
  uuid=$(just generate_uuid)
  short_id=$(just generate_short_id)
  cat > .env <<EOF
  hysteria2_listen_port=8443
  hysteria2_hopping_ports="20000:50000"
  reality_listen_port=443
  user_name="$user_name"
  password="$password"
  private_key="$private_key"
  public_key="$public_key"
  uuid="$uuid"
  short_id="$short_id"
  server_ip="$server_ip"
  EOF

port_hopping:
  just clear_port_hopping_rules
  iptables -t nat -A PREROUTING -i eth0 -p udp --dport $hysteria2_hopping_ports -j REDIRECT --to-ports $hysteria2_listen_port
  ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport $hysteria2_hopping_ports -j REDIRECT --to-ports $hysteria2_listen_port

clear_port_hopping_rules:
  iptables -t nat -F
  ip6tables -t nat -F

ufw:
  ufw allow ssh
  ufw allow $hysteria2_hopping_ports/udp
  ufw allow $hysteria2_listen_port/udp
  ufw allow $reality_listen_port/tcp

optimize:
  sysctl -w net.core.rmem_max=16777216
  sysctl -w net.core.wmem_max=16777216

hysteria2_client_config:
  #!/usr/bin/bash
  cat <<EOF
  {
    "type": "hysteria2",
    "tag": "hysteria2",
    "server": $server_ip,
    "server_port": $hysteria2_listen_port,
    "server_ports": $hysteria2_hopping_ports,
    "up_mbps": 0,
    "down_mbps": 0,
    "password": $password,
    "tls": { "enabled": true, "server_name": "bing.com", "insecure": true },
  },
  EOF

reality_client_config:
  #!/usr/bin/bash
  cat <<EOF
  {
    "type": "vless",
    "tag": "reality",
    "server": $server_ip,
    "server_port": $reality_listen_port,
    "uuid": $uuid,
    "flow": "xtls-rprx-vision",
    "network": "tcp",
    "tls":
    {
      "enabled": true,
      "reality":
      {
        "enabled": true,
        "public_key": $public_key,
        "short_id": $short_id,
      },
      "server_name": "www.tesla.com",
      "utls": { "enabled": true, "fingerprint": "chrome" },
    },
  },
  EOF

install_service:
  #!/usr/bin/bash
  mkdir -p /var/lib/sing-box
  cat > /etc/systemd/system/sing-box-server.service <<EOF
  [Unit]
  Description=Sing-Box Server Service (config.yaml)
  After=network.target

  [Service]
  Type=simple
  ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
  WorkingDirectory=/var/lib/sing-box
  User=root
  Group=root
  CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
  AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
  NoNewPrivileges=true
  Restart=always

  [Install]
  WantedBy=multi-user.target
  EOF

outbounds:
  just hysteria2_client_config
  just reality_client_config

enable:
  systemctl enable sing-box-server.service --now

stop:
  systemctl stop sing-box-server.service

restart:
  systemctl restart sing-box-server.service

disable:
  systemctl disable sing-box-server.service

reload:
  set dotenv-required
  just install_config
  just port_hopping
  just restart
