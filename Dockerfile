FROM ubuntu:18.04

RUN \
    dpkg --add-architecture i386 && \
    apt update && \
    apt install -y bzip2 libstdc++5:i386 libpam0g:i386 libx11-6:i386 \
        expect kmod net-tools iproute2

ADD content/snx_install.sh /snx_install.sh
RUN bash -x /snx_install.sh && rm /snx_install.sh

ADD content/entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
