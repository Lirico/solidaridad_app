# Build authkig with modern libmysqlclient + forced legacy includes.
FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       gcc libc6-dev default-libmysqlclient-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY legacy/bin/iso_common.c \
     legacy/bin/auth_mycli.c \
     legacy/bin/auth_mycli.h \
     legacy/bin/auth_thread.c \
     legacy/bin/auth_conf.c \
     legacy/bin/sock_cli_iso.c \
     legacy/bin/auth_kig.c \
     legacy/bin/auth_kig.h \
     legacy/bin/procesa_carga.c \
     legacy/bin/procesa_descarga.c \
     legacy/bin/compile.sh \
     ./
COPY docker/stubs/legacy_compat.h /src/legacy_compat.h

# Inject -include so struct tm / fcntl resolve; keep MariaDB my_global.h intact.
RUN sed -i 's/^gcc /gcc -include \/src\/legacy_compat.h /' compile.sh \
  && chmod +x compile.sh \
  && MYSQL_INCLUDE=/usr/include/mysql \
     MYSQL_LIB=/usr/lib/x86_64-linux-gnu \
     ./compile.sh \
  && test -x authkig-bin3

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends libmariadb3 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /src/authkig-bin3 /src/libiso_common.so /src/procesa_carga /src/procesa_notas ./
COPY docker/authkig.conf ./authkig.conf
COPY docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh authkig-bin3 procesa_carga procesa_notas \
  && mkdir -p log

ENV LD_LIBRARY_PATH=/app
EXPOSE 4452
ENTRYPOINT ["./entrypoint.sh"]
