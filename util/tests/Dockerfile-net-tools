FROM debian:latest
ENTRYPOINT ["bash"]
RUN apt update && apt upgrade -y \
  curl \
  iperf \
  net-tools \
  traceroute \
  dnsutils \
  vim
