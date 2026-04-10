FROM nginx:1.27-alpine

RUN apk add --no-cache apache2-utils

RUN mkdir -p /etc/nginx/templates

COPY nginx.conf /etc/nginx/templates/nginx.conf
COPY nginx.admin.conf /etc/nginx/templates/nginx.admin.conf
COPY nginx.collect.conf /etc/nginx/templates/nginx.collect.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
