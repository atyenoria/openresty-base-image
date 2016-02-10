#docker build -t atyenoria/openresty-base . && docker run -it atyenoria/openresty-base bash
FROM debian:jessie

#openresty
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    curl perl lsof wget make build-essential procps unzip \
    libreadline-dev libncurses5-dev libpcre3-dev libssl-dev ca-certificates\
 && rm -rf /var/lib/apt/lists/*

#delete v!!
ENV OPENRESTY_VERSION 1.9.7.3
ENV NPS_VERSION=1.9.32.10
ENV NGINX_UP_CHECK=0.3.0

ENV NGX_PAGESPEED_DOWNLOAD_URL="https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}-beta.tar.gz" \
    PSOL_DOWNLOAD_URL="https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz" \
    NGINX_UP_CHECK_URL="https://github.com/yaoweibin/nginx_upstream_check_module/archive/v${NGINX_UP_CHECK}.tar.gz"

ENV OPENRESTY_PREFIX /opt/openresty
ENV NGINX_PREFIX /opt/openresty/nginx
ENV VAR_PREFIX /var/nginx
ENV NGINX_SETUP_DIR=/var/cache/nginx
ENV TEMP_PACKAGES="build-essential"

COPY setup/ ${NGINX_SETUP_DIR}/
RUN bash ${NGINX_SETUP_DIR}/download_and_extract.sh "${NGX_PAGESPEED_DOWNLOAD_URL}" "${NGINX_SETUP_DIR}/ngx_pagespeed"
RUN bash ${NGINX_SETUP_DIR}/download_and_extract.sh "${PSOL_DOWNLOAD_URL}" "${NGINX_SETUP_DIR}/ngx_pagespeed/psol"
RUN bash ${NGINX_SETUP_DIR}/download_and_extract.sh "${NGINX_UP_CHECK_URL}" "${NGINX_SETUP_DIR}/nginx_upstream_check_module"

# NginX prefix is automatically set by OpenResty to $OPENRESTY_PREFIX/nginx
# look for $ngx_prefix in https://github.com/openresty/ngx_openresty/blob/master/util/configure

RUN cd /root \
 && echo "==> Downloading OpenResty..." \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && echo "==> Configuring OpenResty..." \
 && cd openresty-* \
 && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && echo "using upto $NPROC threads" \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
    --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
    --http-log-path=$VAR_PREFIX/access.log \
    --error-log-path=$VAR_PREFIX/error.log \
    --pid-path=$VAR_PREFIX/nginx.pid \
    --lock-path=$VAR_PREFIX/nginx.lock \
    --http-fastcgi-temp-path=$VAR_PREFIX/fastcgi \
    --http-scgi-temp-path=$VAR_PREFIX/scgi \
    --http-uwsgi-temp-path=$VAR_PREFIX/uwsgi \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_ssl_module \
    --without-http_ssi_module \
    --with-http_gzip_static_module \
    --without-http_userid_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    --add-module=${NGINX_SETUP_DIR}/ngx_pagespeed \
    --add-module=${NGINX_SETUP_DIR}/nginx_upstream_check_module \
    -j${NPROC} \
 && echo "==> Building OpenResty..." \
 && make -j${NPROC} \
 && echo "==> Installing OpenResty..." \
 && make install \
 && echo "==> Finishing..." \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua \
 && rm -rf /root/ngx_openresty*


#clean up
# RUN apt-get remove --purge -y ${TEMP_PACKAGES} && \
#     apt-get autoremove -y && \
#     apt-get clean && \
#     apt-get autoclean && \
#     echo -n > /var/lib/apt/extended_states && \
#     rm -rf /var/lib/apt/lists/* && \
#     rm -rf /usr/share/man/?? && \
#     rm -rf /usr/share/man/??_*


WORKDIR $NGINX_PREFIX/


ENV VER_LUAROCKS=2.3.0
RUN wget https://github.com/keplerproject/luarocks/archive/v${VER_LUAROCKS}-rc2.tar.gz
RUN tar -xzvf v${VER_LUAROCKS}-rc2.tar.gz && rm v${VER_LUAROCKS}-rc2.tar.gz
RUN cd luarocks-${VER_LUAROCKS}-rc2 && ./configure --prefix=/opt/openresty/luajit --lua-suffix=jit --with-lua=/opt/openresty/luajit --with-lua-include=/opt/openresty/luajit/include/luajit-2.1 --with-lua-lib=/opt/openresty/luajit/lib && make build && make install && ls
RUN echo "PATH=/opt/openresty/luajit/bin/:\$PATH" >> ~/.bashrc


RUN /opt/openresty/luajit/bin/luarocks install lua-cjson
RUN /opt/openresty/luajit/bin/luarocks install md5


RUN mkdir -p /opt/openresty/nginx/logs
RUN touch /opt/openresty/nginx/logs/nginx.pid
RUN echo "alias ngx=\"nginx -c /etc/nginx/nginx.conf\"" >> ~/.bashrc
RUN echo "alias lso=\"lsof -i -n -P\"" >> ~/.bashrc
RUN echo "alias ls=\"ls --color\"" >> ~/.bashrc
RUN echo "alias l=\"ls -la\"" >> ~/.bashrc

# COPY ./test /opt/openresty/nginx



# nginx -c /etc/nginx/nginx.conf
RUN echo "cd /opt/openresty/nginx/test" >> ~/.bashrc
RUN echo "alias r=\"resty\"" >> ~/.bashrc
RUN echo "alias ng=\"nginx -p /opt/openresty/nginx/test -c\"" >> ~/.bashrc


# ONBUILD RUN rm -rf conf/* html/*
# ONBUILD COPY nginx $NGINX_PREFIX/

CMD ["nginx", "-g", "daemon off; error_log /dev/stderr info;"]
