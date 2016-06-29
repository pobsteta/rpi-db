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
RUN wget --no-check-certificate -O postgresql-9.5.3-raspbian.tar.gz https://pascalobstetar.cozycloud.cc/public/files/files/1b56144d036da9fa913c41ea029830b2/attach/postgresql-9.5.3-raspbian.tar.gz
RUN tar -xvzf postgresql-9.5.3-raspbian.tar.gz
#RUN echo "deb [ trusted=yes ] file:///var/local/repository ./" | sudo tee /etc/apt/sources.list.d/my_own_repo.list
#RUN dpkg-scanpackages ./ | sudo tee Packages > /dev/null && sudo gzip -f Packages
RUN apt-get update
RUN apt-get install -y libssl-dev krb5-multidev comerr-dev libgssapi-krb5-2 libldap-2.4-2
RUN dpkg -i libpq5_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i libpq-dev_9.5.3-1.pgdg80+1_armhf.deb
RUN dpkg -i postgresql-server-dev-all_175.pgdg80+1_all
RUN dpkg -i postgis_2.2.0-1_armhf.deb

# On installe Postgres
RUN apt-get update \
	&& apt-get install -y postgresql-common \
	&& sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
	&& apt-get install -y \
		postgresql-$PG_MAJOR \
		postgresql-contrib-$PG_MAJOR
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
