FROM perl:5.28.2-threaded

ENV LANG C.UTF-8
ENV TZ Asia/Tokyo

RUN cpanm Carton

ARG uid=1000
ARG gid=1000
RUN useradd app -ms /bin/bash -u $uid && \
    groupmod -g $gid app
USER app

WORKDIR /app
