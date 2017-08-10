FROM debian:stretch
MAINTAINER Tobias Adolph

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -yq \
      apt-utils \
      curl \
      gnupg \
      python \
      python-yaml

RUN curl -sL https://deb.nodesource.com/setup_6.x | bash -

RUN apt-get update \
    && apt-get install -y nodejs

RUN npm install -g @htmlacademy/editorconfig-cli
