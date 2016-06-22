# PostgreSQL stack
#
# This image includes the following tools
# - PostgreSQL 9.5
# - Postgis 2.2
# - SIME 2.8
#
# Version 1.0

# Image de base ubuntu modifiée
FROM resin/rpi-raspbian:wheezy
MAINTAINER Pascal Obstetar <pascal.obstetar@bioecoforests.com>

# ---------- DEBUT --------------

# On évite les messages debconf
ENV DEBIAN_FRONTEND noninteractive

# On explicite user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates

# Les versions de PostgreSQL/Postgis à installer
ENV PG_MAJOR 9.4
ENV POSTGIS_MAJOR 2.1

RUN apt-get update \
	&& apt-get install -y postgresql-common \
	&& apt-get install -y \
		postgresql-$PG_MAJOR \
		postgresql-contrib-$PG_MAJOR \
		postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
        postgis \
	&& rm -rf /var/lib/apt/lists/*

# On met les fichiers de configuration de Postgres en place
ADD postgres.conf /etc/supervisor/conf.d/postgres.conf

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

CMD /init-pg.sh
#CMD ["postgres"]

# ---------- FIN --------------
#
# Nettoie les APT
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*
