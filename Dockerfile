FROM python:3.9.1-slim

RUN groupadd -r pytree && useradd -r -m -g pytree pytree

USER pytree
# Sane defaults for pip
ENV PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  HOME=/home/pytree \
  PATH=$PATH:$HOME/.local/bin
WORKDIR $HOME

COPY --chown=pytree:pytree . ./
USER root

RUN   mv ./bin/extract_profile /usr/local/bin/ \
  && mv ./bin/liblaszip.so /usr/local/lib/ \
  && ldconfig

RUN echo $PATH
RUN pip3 install -r requirements.txt

CMD ["./start_server.sh"]
