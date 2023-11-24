FROM ubuntu:22.04 AS cpotree

RUN --mount=type=cache,target=/var/lib/apt/lists \
  --mount=type=cache,target=/var/cache,sharing=locked \
  apt-get update \
  && apt-get install --assume-yes build-essential git cmake python3 \
  zlib1g-dev libssl-dev libcurlpp-dev

WORKDIR /opt/

RUN git clone --recurse-submodules https://github.com/aws/aws-sdk-cpp.git \
    && cd aws-sdk-cpp \
	&& git checkout 1.11.205

WORKDIR /opt/aws-sdk-cpp/build

RUN --mount=type=cache,target=/opt/aws-sdk-cpp/build \
  cmake .. -DCMAKE_TOOLCHAIN_FILE=../toolchains/gcc-c++20.cmake -DBUILD_ONLY="s3" \
  && cmake --build . \
  && cmake --install .

WORKDIR /opt

RUN --mount=type=cache,target=/var/lib/apt/lists \
  --mount=type=cache,target=/var/cache,sharing=locked \
  apt-get update \
  && apt-get install --assume-yes curl

RUN git clone --branch=aws --depth=1 https://github.com/camptocamp/CPotree.git

WORKDIR /opt/CPotree/build

RUN --mount=type=cache,target=/opt/CPotree/build \
  cmake .. -DWITH_AWS_SDK=ON -DCMAKE_BUILD_TYPE=Debug \
  && make \
  && cp extract_profile /usr/local/bin/ \
  && cp liblaszip.so /usr/local/lib/


#######################################################################################################

FROM ubuntu:22.04 as runner

ENV PIP_ROOT_USER_ACTION=ignore

RUN --mount=type=cache,target=/var/lib/apt/lists \
  --mount=type=cache,target=/var/cache,sharing=locked \
  apt-get update \
  && apt-get upgrade --assume-yes \
  && apt-get install --assume-yes --no-install-recommends python3 python-is-python3 python3-pip libcurlpp-dev

WORKDIR /app

COPY requirements.txt ./

RUN pip3 install -r requirements.txt

RUN --mount=type=cache,target=/var/lib/apt/lists \
  --mount=type=cache,target=/var/cache,sharing=locked \
  apt-get update \
  && apt-get install --assume-yes gdb

COPY . /app

COPY --from=cpotree /usr/local/lib/libaws-cpp-sdk-core.so /usr/local/lib/
COPY --from=cpotree /usr/local/lib/libaws-cpp-sdk-s3.so /usr/local/lib/
COPY --from=cpotree /usr/local/bin/extract_profile /usr/local/bin/
COPY --from=cpotree /usr/local/lib/liblaszip.so /usr/local/lib/

ENV LD_LIBRARY_PATH=/usr/local/lib

CMD ["gunicorn", "--config=gunicorn_config.py", "wsgi:app"]
