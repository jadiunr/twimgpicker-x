FROM perl:5.28.1-threaded

ENV LANG C.UTF-8
ENV TZ Asia/Tokyo

RUN cpanm Carton

WORKDIR /app
