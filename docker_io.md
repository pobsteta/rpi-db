Docker notes
============

Utiliser le dépôt docker
------------------------

Se logguer au serveur docker et pousser l'image sur le serveur.

```sh
sudo docker login
sudo docker push pobsteta/gf-db
```

Recevoir l'image du serveur docker :

```sh
sudo docker pull pobsteta/gf-db
```

Utiliser Trusted Build
----------------------

Pour automatiser les builds successifs, renseigner sur le serveur docker Trusted Builds

Chaque commit réalisé sur le dépôt GitHub réalisera un build automatiquement sur le serveur Docker.
Cette nouvelle version sera tagguée pobsteta/gf-db:latest

Pour plus d'informations sur Trusted Build : http://docs.docker.io/docker-io/builds/
