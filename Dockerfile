FROM debian:stretch-slim
RUN apt-get update &&\ 
    apt-get install -y locales &&\
    rm -rf /var/lib/apt/lists/* &&\
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# install essential pakages
RUN apt-get update &&\
    apt-get install -y -qq --no-install-recommends --fix-missing \
	    wget tk-dev gcc make libapr1-dev libaprutil1-dev libaprutil1-ldap net-tools\   
            liblua5.2-dev ca-certificates libnghttp2-dev libpcre3-dev libssl-dev libxml2-dev;

#install Python
ENV PYTHON_VERSION 3.6.8
ENV PATH /usr/local/bin:$PATH
RUN set -ex \
        mkdir -p /tmp &&\
        wget -O /tmp/python.tar.gz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tgz" &&\
        tar -zxvf /tmp/python.tar.gz &&\
        rm /tmp/python.tar.gz &&\
        cd Python-$PYTHON_VERSION &&\
        gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" &&\
        ./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-shared \
		--with-system-expat \
		--with-system-ffi \
		--without-ensurepip \
        &&\
        make -j "$(nproc)" &&\
        make install &&\
	ldconfig &&\
        cd .. &&\
        rm -rf /tmp &&\
        rm -rf Python-$PYTHON_VERSION &&\
        python3 --version;

ENV PYTHON_PIP_VERSION 19.1

RUN set -ex; \
	mkdir -p /tmp &&\
	wget -O /tmp/get-pip.py 'https://bootstrap.pypa.io/get-pip.py' &&\
	python3 /tmp/get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	&&\
	rm -rf /tmp &&\
        pip3 --version



# add Apache Webserver
ENV HTTPD_PREFIX /usr/local/apache2
ENV HTTPD_VERSION 2.4.39
ENV PATH $HTTPD_PREFIX/bin:$PATH

RUN set -ex; \
        rm -rf /var/lib/apt/lists/* &&\
        mkdir -p /tmp &&\
        wget -O /tmp/httpd.tar.gz https://www-eu.apache.org/dist//httpd/httpd-$HTTPD_VERSION.tar.gz &&\
        tar -zxvf /tmp/httpd.tar.gz &&\
        rm /tmp/httpd.tar.gz &&\
        cd httpd-$HTTPD_VERSION &&\
        gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" &&\
        ./configure \
	    --build="$gnuArch" \
	    --prefix="$HTTPD_PREFIX" \
	    --enable-mods-shared=reallyall \
	    --enable-mpms-shared=all \
            --enable-ldap=shared \
            --enable-lua=shared \
            --with-port=80 \
        &&\
        make -j "$(nproc)" &&\
        make install &&\
        cd .. &&\
        rm -rf /tmp &&\
        rm -rf httpd-$HTTPD_VERSION &&\
	sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		-e 's!^(\s*TransferLog)\s+\S+!\1 /proc/self/fd/1!g' \
		"$HTTPD_PREFIX/conf/httpd.conf" \
		"$HTTPD_PREFIX/conf/extra/httpd-ssl.conf" \
	&&\
        httpd -v;

EXPOSE 80

# install Flask, and  other Python packages
RUN pip3 install Flask

# install mod_wsgi
ENV MOD_WSGI_VERSION 4.6.5
RUN set -ex; \
	mkdir -p /tmp &&\
	wget -O /tmp/mod_wsgi.tar.gz https://github.com/GrahamDumpleton/mod_wsgi/archive/$MOD_WSGI_VERSION.tar.gz &&\
        tar -zxvf /tmp/mod_wsgi.tar.gz &&\
        rm /tmp/mod_wsgi.tar.gz &&\
        cd mod_wsgi-$MOD_WSGI_VERSION &&\
        ./configure \
            --with-apx=/usr/local/apache2/bin/apxs \
            --with-python=/usr/local/bin/python3.6 \
        &&\
        make &&\
        make install clean &&\
        cd .. &&\
        rm -rf /tmp &&\
        rm -rf mod_wsgi-$MOD_WSGI_VERSION

# copy files from Local machine into Containe
COPY ./wsgi.conf /usr/local/apache2/conf/httpd.conf
COPY app /usr/local/python/app
# COPY ./min.conf /usr/local/apache2/conf/httpd.conf
# COPY ./index.html /usr/local/apache2/htdocs/

#Start server when run Container
ENTRYPOINT ["httpd", "-D", "FOREGROUND", "-e", "info"]




