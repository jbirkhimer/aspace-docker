FROM nginx:stable

RUN  sed -i '/http {/c\http {\n    include /aspace/nginx/conf/tenants/\*.conf;' /etc/nginx/nginx.conf