FROM haproxy:1.9-alpine

ENTRYPOINT ["entrypoint"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
EXPOSE 433

ADD ./rootfs /
