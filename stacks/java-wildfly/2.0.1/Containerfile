ARG IMAGE_VERSION=latest-jdk17

FROM quay.io/wildfly/wildfly-s2i:$IMAGE_VERSION AS builder

ENV MVN_ARGS_APPEND="-s /home/jboss/.m2/settings.xml -Dmaven.repo.local=/home/jboss/.m2/repository -Dcom.redhat.xpaas.repo.jbossorg"
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/urandom"
ENV S2I_DESTINATION_DIR=/build

WORKDIR /build
RUN mkdir src
COPY --chown=jboss:root pom.xml .
COPY --chown=jboss:root src src
RUN mvn $MVN_ARGS_APPEND -Popenshift -Dmaven.test.skip=true clean package

FROM quay.io/wildfly/wildfly-runtime:$IMAGE_VERSION AS runtime

COPY --chown=jboss:root --from=builder  /build/target/server $JBOSS_HOME
RUN chmod -R ug+rwX $JBOSS_HOME 
EXPOSE 8080