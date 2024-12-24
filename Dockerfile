FROM alpine:latest AS systemctl

RUN apk add git
RUN git clone https://github.com/gdraheim/docker-systemctl-replacement /docker-systemctl-replacement

# systemd just doesn't work in docker containers, and mariadb is
# incompatible with it.  instead, just have a script that does 'exit
# 0' or something.

FROM debian:bookworm-slim

RUN apt-get update
RUN apt-get install --no-install-recommends -y python3 git perl systemd build-essential certbot git libdb-dev libexpat1-dev libgetopt-long-descriptive-perl libpath-tiny-perl libssl-dev nginx python3-certbot-nginx unzip zlib1g-dev libsasl2-modules ufw curl sudo openssh-server

COPY --from=systemctl /docker-systemctl-replacement/files/docker/systemctl3.py /usr/bin/systemctl

RUN adduser pause --disabled-password --comment 'PAUSE User'

COPY --chown=pause . /home/pause/pause

RUN apt-get install --no-install-recommends -y gpg gpg-agent

RUN /home/pause/pause/bootstrap/selfconfig-root --enable-certbot=0 --enable-ufw=0 --host unpause --user admin --pass admin --plenv-url https://dot-plenv.nyc3.digitaloceanspaces.com/dot-plenv.tar.bz2 && rm -rf /home/pause/.plenv/build /home/pause/.plenv/cache /tmp/plenv-tarball.tar.bz2

CMD ["/usr/bin/systemctl"]