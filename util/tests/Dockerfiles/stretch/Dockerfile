FROM debian:stretch-slim

RUN apt update && apt upgrade -y \
  curl \
  iperf \
  net-tools \
  traceroute \
  dnsutils \
  iputils-ping \
  iproute2 \
  tcpdump \
  vim

ENTRYPOINT ["bash"]
