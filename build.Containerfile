FROM debian:11
#MAINTAINER carbon severac (carbon.severac@tuta.io)
LABEL maintainer="carbon"

#Update the image to the latest packages
RUN apt-get update && apt-get upgrade -y

#Install package for build .deb and .rpm
RUN apt install -y dpkg git alien rsync pandoc debhelper

#Add volume and project
VOLUME /project
WORKDIR /project

CMD ["/project/tools/build-package.sh", "-f", "/project/output", "/project" ]
