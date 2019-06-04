FROM alpine:latest

RUN apk add --no-cache --virtual .build-deps \
                curl \
                iperf \
                net-tools \
                iputils \
                bind-tools \
                tcpdump \
                vim \
    && rm -rf /var/cache/apk/*

ENTRYPOINT ["sh"]
