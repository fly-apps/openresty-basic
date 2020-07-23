# Because of: https://github.com/openresty/docker-openresty/issues/124
FROM openresty/openresty:1.15.8.1-4-centos

USER root

RUN echo -e "env FLY_REDIS_CACHE_URL;\n$(cat /usr/local/openresty/nginx/conf/nginx.conf)" > /usr/local/openresty/nginx/conf/nginx.conf

RUN echo "T7"
# Remove the default configs
RUN rm /etc/nginx/conf.d/*
# Copy the custom NGINX config files
COPY proxy.conf /etc/nginx/conf.d/proxy.conf
COPY split.lua /etc/nginx/conf.d/split.lua
