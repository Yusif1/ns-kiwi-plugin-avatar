# Gravatar Plugin for [Kiwi IRC](https://kiwiirc.com)

This is the server side for plugin-gravatar. It can run as a webircgateway plugin or as a standalone server.

## Webircgateway plugin

To run this as a webircgateway plugin copy `plugin.go` to `webircgateway/plugins/gravatar/plugin.go` before building.

Follow webircgateway instructions for building with plugins.

To specify config loading location you can use `--config-gravatar /etc/kiwiirc/gravatar.config.json` as a run param.

_Note: don't forget to set "salt" in `gravatar.config.json`._

## Standalone

To build this as a standalone service:

```bash
go build -o gravatar-service *.go
```

You will also need to add some items to `gravatar.config.json`:

```json
"listen_addr": "127.0.0.1:4646",
"allow_origins": ["*"]
```

## Hiding the server IP and showing users' real IPs

There are three pieces to this puzzle:

| Layer | Problem | Solution |
|---|---|---|
| User -> Server | Users can see the real server IP | Put nginx/Cloudflare in front |
| nginx -> webircgateway | Backend sees nginx IP, not user IP | `X-Forwarded-For` headers + `reverse_proxies` in gateway config |
| webircgateway -> IRCd | IRCd sees gateway IP, not user IP | WEBIRC protocol |

### Step 1: nginx reverse proxy (hides the server IP)

Users connect to nginx only. Your real server IP is never exposed.

```nginx
server {
    listen 443 ssl;
    server_name irc.example.com;

    ssl_certificate     /etc/ssl/certs/irc.example.com.pem;
    ssl_certificate_key /etc/ssl/private/irc.example.com.key;

    # Prevent leaking server software info
    server_tokens off;
    proxy_hide_header X-Powered-By;

    # WebSocket endpoint (webircgateway)
    location /webirc/ {
        proxy_pass http://127.0.0.1:7778;
        proxy_http_version 1.1;

        # Required for WebSocket upgrade
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Pass the real user IP to the backend
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket timeouts
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
    }

    # Gravatar endpoint (this plugin, standalone mode)
    location /gravatar/ {
        proxy_pass http://127.0.0.1:4646;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Step 2: webircgateway reads the real user IP from headers

In your webircgateway `config.conf`, tell it to trust your reverse proxy so it reads `X-Forwarded-For` instead of using the proxy's IP:

```ini
[server]
; Bind to localhost only -- nginx handles public traffic
listen = 127.0.0.1:7778

[reverse_proxies]
; Trust nginx on localhost to provide the real user IP
; via X-Forwarded-For / X-Real-IP headers
127.0.0.1 = true
::1 = true

[client]
; The gateway now resolves the real user IP from the
; X-Forwarded-For header set by nginx above
```

For the **gravatar standalone** server, configure `trusted_proxies` in `gravatar.config.json`:

```json
{
    "listen_addr": "127.0.0.1:4646",
    "trusted_proxies": ["127.0.0.1", "::1"]
}
```

Accepts single IPs or CIDR notation (e.g. `10.0.0.0/8`). Only requests from trusted proxies will have their forwarded headers respected, preventing spoofing.

### Step 3: WEBIRC (makes IRC server show the user's real IP)

Without WEBIRC, every user appears to connect from the gateway's IP on IRC. WEBIRC tells the IRCd the real user IP before registration.

**webircgateway `config.conf`:**

```ini
[upstream]
; The hostname or IP of your IRC server
hostname = 127.0.0.1
port = 6667
tls = false

; WEBIRC password -- must match what's in your IRCd config
webirc = your_secret_webirc_password
```

**IRCd config (UnrealIRCd example):**

```
webirc {
    mask 127.0.0.1;
    password "your_secret_webirc_password";
};
```

**IRCd config (InspIRCd example):**

```xml
<connect name="webirc"
         allow="127.0.0.1"
         webirc="your_secret_webirc_password">
```

**IRCd config (ircd-hybrid / Charybdis / Solanum):**

```
auth {
    user = "cgiirc@127.0.0.1";
    password = "your_secret_webirc_password";
    spoof = "webirc.";
    class = "users";
};
```

### How it all flows

```
User (real IP: 203.0.113.50)
  |
  |  HTTPS / WSS
  v
nginx (public IP: 198.51.100.10)
  |
  |  proxy_set_header X-Forwarded-For: 203.0.113.50
  v
webircgateway (127.0.0.1:7778)
  |  reads X-Forwarded-For because 127.0.0.1 is a trusted reverse_proxy
  |
  |  WEBIRC your_secret_webirc_password cgiirc 203.0.113.50 :203.0.113.50
  v
IRCd
  |  sees user as connecting from 203.0.113.50, not 127.0.0.1
```

- Users only see `198.51.100.10` (nginx) -- the real server IP is hidden
- The IRCd sees `203.0.113.50` (the user) -- not the gateway IP
