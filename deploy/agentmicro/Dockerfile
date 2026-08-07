FROM nginx:1.27-alpine

COPY deploy/agentmicro/nginx.conf /etc/nginx/conf.d/default.conf
COPY docs/agentmicro/ /usr/share/nginx/html/
COPY docs/agentmicro-logo-macos27-light.png /usr/share/nginx/html/agentmicro-logo-macos27-light.png
COPY docs/screenshots/agentmicro-menu.png /usr/share/nginx/html/screenshots/agentmicro-menu.png
