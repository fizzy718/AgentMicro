# AgentMicro landing-page deployment

This directory defines the production container for `agentmicro.cc`.

The container serves the hand-authored page from `docs/agentmicro/`, plus the
two published visual assets that it references. It binds only to localhost on
port 8089; the host Nginx configuration owns the public HTTP/HTTPS endpoint
and proxies requests to the container.

`host-nginx.conf` is the initial virtual-host configuration for `agentmicro.cc`.
Install it alongside the host's other Nginx configurations, validate Nginx, and
then use Certbot's Nginx integration to provision and renew the certificate.

From the repository root, build and start it with:

```sh
docker compose -f deploy/agentmicro/docker-compose.yml up -d --build
```
