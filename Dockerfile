# Using this base image because of: https://github.com/openresty/docker-openresty/issues/124
FROM openresty/openresty:1.15.8.1-4-centos

# Add the REDIS connection URL as an env variable in NGINX
RUN echo -e "env FLY_REDIS_CACHE_URL;\n$(cat /usr/local/openresty/nginx/conf/nginx.conf)" > /usr/local/openresty/nginx/conf/nginx.conf

# Add the configuration and lua files
RUN rm /etc/nginx/conf.d/*
COPY proxy.conf /etc/nginx/conf.d/proxy.conf
COPY split.lua /etc/nginx/conf.d/split.lua
