FROM python:3.9-slim

RUN groupadd -r pytree && useradd -r -m -g pytree pytree
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libtbb2 \
    && rm -rf /var/lib/apt/lists/*

USER pytree
# Sane defaults for pip
ENV PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  HOME=/home/pytree
ENV PATH=$PATH:$HOME/.local/bin
WORKDIR $HOME

COPY --chown=pytree:pytree . ./

USER root
RUN cp ./bin/extract_profile /usr/local/bin/ \
  && mv ./bin/liblaszip.so /usr/local/lib/ \
  && ldconfig

USER pytree
RUN pip3 install -r requirements.txt gunicorn

CMD ["./start_server.sh"]
