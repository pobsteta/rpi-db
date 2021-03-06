# PostgreSQL stack
#
# This image includes the following tools
# - PostgreSQL 9.5
# - Postgis 2.2
# - SIME 2.8
#
# Version 1.0

# Image de base resin/rpi-paspbian modifiée
FROM resin/rpi-raspbian
MAINTAINER Pascal Obstetar <pascal.obstetar@bioecoforests.com>

# ---------- DEBUT --------------

# On évite les messages debconf
ENV DEBIAN_FRONTEND noninteractive

# On explicite user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget rpl pwgen build-essential fakeroot \
    && rm -rf /var/lib/apt/lists/* \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

# Ajouter les dépôts pg
RUN echo "deb-src http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Ajouter la clef du dépôt
RUN wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# On met la locale à "fr_FR.UTF-8" pour que Postgres soit en français par défaut
RUN apt-get update && apt-get upgrade && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i fr_FR -c -f UTF-8 fr_FR.UTF-8
ENV LANG fr_FR.utf8

# Les versions de PostgreSQL/Postgis à installer
ENV PG_MAJOR 9.5
ENV POSTGIS_MAJOR 2.2

# Créer un dépôt local
RUN mkdir /var/local/repository \
    && cd /var/local/repository
RUN wget --no-check-certificate -O postgresql-9.5.3-raspbian.tar.gz https://pascalobstetar.cozycloud.cc/public/files/files/1b56144d036da9fa913c41ea02985654/attach/postgresql-9.5.3-raspbian.tar.gz
RUN tar -xvzf postgresql-9.5.3-raspbian.tar.gz

# On met à jour
RUN apt-get update

# On installe les dépendances nécessaires à Postgres et Postgis
RUN apt-get install -y autoconf build-essential cmake docbook-mathml docbook-xsl libboost-dev libboost-thread-dev libboost-filesystem-dev libboost-system-dev libboost-iostreams-dev libboost-program-options-dev libboost-timer-dev libcunit1-dev libgdal-dev libgeos++-dev libgeotiff-dev libgmp-dev libjson0-dev libjson-c-dev liblas-dev libmpfr-dev libopenscenegraph-dev libpq-dev libproj-dev libxml2-dev xsltproc build-essential 

RUN apt-get install -y libssl-dev krb5-multidev comerr-dev libgssapi-krb5-2 libldap-2.4-2 dctrl-tools iproute2 net-tools lsb-release libxml2 ssl-cert netbase ucf libedit2

# On installe Postgres et Postgis
RUN dpkg -i cgal-4.3_20160628-1_armhf.deb
RUN dpkg -i gdal-stable_4.8-1_armhf.deb
RUN dpkg -i geos_3.5.0-1_armhf.deb
RUN dpkg -i proj4_4.8-1_armhf.deb
RUN dpkg -i sfcgal_20160628-1_armhf.deb
RUN dpkg -i libpgtypes3_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libecpg6_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libecpg-compat3_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libecpg-dev_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libpq5_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libpq-dev_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libpq5_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libpq-dev_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i pgdg-keyring_2014.1_all.deb
RUN dpkg -i postgresql-client-common_175.pgdg80+1_all.deb
RUN dpkg -i postgresql-common_175.pgdg80+1_all.deb
RUN dpkg -i postgresql-client-9.5_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i postgresql-9.5_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i postgresql-contrib-9.5_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i postgis_2.2.0-1_armhf.deb

# On paramètre Postgres
RUN sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
    && rm -rf /var/lib/apt/lists/*

# On met les fichiers de configuration de Postgres en place
RUN mv -v /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample /usr/share/postgresql/ \
    && ln -sv ../postgresql.conf.sample /usr/share/postgresql/$PG_MAJOR/ \
    && sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME ["/var/lib/postgresql/data"]

# Crée le répertoire docker-entrypoint-initdb.d
RUN mkdir /docker-entrypoint-initdb.d

# Copie le script de création des bases de données de sauvegarde tryton
COPY ./init-tryton-sql.sh /docker-entrypoint-initdb.d/01-init-tryton-sql.sh
RUN chmod 700 /docker-entrypoint-initdb.d/01-init-tryton-sql.sh

# Copie le script de création des bases de données postgis
COPY ./init-postgis-db.sh /docker-entrypoint-initdb.d/02-init-postgis-db.sh
RUN chmod 700 /docker-entrypoint-initdb.d/02-init-postgis-db.sh

# Création du répertoire de sauvegarde des fichiers SQL
RUN mkdir -p /data/restore

COPY init-pg.sh /
RUN chmod 700 /init-pg.sh

ENTRYPOINT ["/init-pg.sh"]

EXPOSE 5432

CMD ["postgres"]

# ---------- FIN --------------
#
# Nettoie les APT
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*
