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

## Reverse proxy setup (hiding server IP / resolving real user IP)

When running behind a reverse proxy (nginx, Cloudflare, etc.), the server sees the **proxy's IP** instead of the real client IP. Configure `trusted_proxies` so the server extracts the real user IP from `X-Forwarded-For` / `X-Real-IP` headers:

```json
"trusted_proxies": ["127.0.0.1", "::1", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
```

Accepts single IPs or CIDR notation. Only requests arriving from a trusted proxy will have their forwarded headers respected (prevents spoofing).

### Example nginx config

```nginx
server {
    listen 443 ssl;
    server_name irc.example.com;

    location /gravatar/ {
        proxy_pass http://127.0.0.1:4646;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /webirc/ {
        proxy_pass http://127.0.0.1:7778;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

This setup:
- **Hides the real server IP** from users (they only see the proxy/CDN IP)
- **Passes the real user IP** to the backend via `X-Forwarded-For` / `X-Real-IP`
- The backend resolves the real client IP from those headers when the request comes from a trusted proxy

### webircgateway WEBIRC support

To make the IRC server show users' real IPs instead of the gateway's IP, configure WEBIRC in your webircgateway `config.conf`:

```ini
[upstream]
webirc = password_agreed_with_ircd
```

And add a matching WEBIRC block to your IRC server config (e.g. for UnrealIRCd):

```
webirc {
    mask 127.0.0.1;
    password "password_agreed_with_ircd";
};
```
