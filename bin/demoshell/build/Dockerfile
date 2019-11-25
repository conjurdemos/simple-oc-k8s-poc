FROM frolvlad/alpine-glibc

ENV DOCKERVERSION=18.03.1-ce
ENV OPENSHIFT_VERSION=v3.9.0
ENV OPENSHIFT_HASH=191fece
ENV MINISHIFT_VERSION=1.21.0
ENV OS_PLATFORM=linux

RUN apk add --no-cache	bash \
			jq \
			wget \
			curl \
			tar \
			git \
			docker \
    && rm -rf \
       /tmp/* \
       /var/lib/apt/lists/* \
       /var/tmp/*

RUN apk add --no-cache --virtual .build-deps \
    && curl --retry 7 -Lso /tmp/client-tools.tar.gz "https://github.com/openshift/origin/releases/download/${OPENSHIFT_VERSION}/openshift-origin-client-tools-${OPENSHIFT_VERSION}-${OPENSHIFT_HASH}-linux-64bit.tar.gz" \
    && tar zxf /tmp/client-tools.tar.gz --strip-components=1 -C /usr/local/bin \
    && rm /tmp/client-tools.tar.gz \
    && apk del .build-deps

RUN git clone https://github.com/jodyhuntatx/dap-demo-env.git

RUN curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-$OS_PLATFORM-amd64 \
  && chmod +x minikube \
  && mv minikube /usr/local/bin \
  && curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/v1.13.2/bin/linux/amd64/kubectl \
  && chmod +x kubectl \
  && mv kubectl /usr/local/bin/

RUN wget https://github.com/minishift/minishift/releases/download/v$MINISHIFT_VERSION/minishift-$MINISHIFT_VERSION-$OS_PLATFORM-amd64.tgz \
  && tar xvzf minishift-$MINISHIFT_VERSION-$OS_PLATFORM-amd64.tgz \
  && cd minishift-$MINISHIFT_VERSION-$OS_PLATFORM-amd64 \
    && chmod +x minishift \
    && mv minishift /usr/local/bin \
  && cd .. \
  && rm -rf minishift-$MINISHIFT_VERSION-$OS_PLATFORM-amd64*

WORKDIR /dap-demo-env
