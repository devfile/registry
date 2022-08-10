#!/bin/sh


ginkgo run --procs 2 \
  --skip="stack: java-openliberty-gradle starter: rest" \
  --skip="stack: java-vertx starter: vertx-cache-example-redhat" \
  --skip="stack: java-vertx starter: vertx-cache-example" \
  --skip="stack: java-vertx starter: vertx-circuit-breaker-example-redhat" \
  --skip="stack: java-vertx starter: vertx-circuit-breaker-example" \
  --skip="stack: java-vertx starter: vertx-crud-example-redhat" \
  --skip="stack: java-vertx starter: vertx-crud-example" \
  --skip="stack: java-vertx starter: vertx-http-example-redhat" \
  --skip="stack: java-vertx starter: vertx-istio-circuit-breaker-booster" \
  --skip="stack: java-vertx starter: vertx-istio-distributed-tracing-booster" \
  --skip="stack: java-vertx starter: vertx-istio-routing-booster" \
  --skip="stack: java-vertx starter: vertx-istio-security-booster" \
  --skip="stack: java-vertx starter: vertx-messaging-work-queue-booster" \
  --skip="stack: java-websphereliberty-gradle starter: rest" \
  --skip="stack: java-wildfly-bootable-jar" \
  --skip="stack: java-wildfly" \
  --slow-spec-threshold 120s \
  --timeout 2h \
  tests/odov3 -- -stacksDir "$(pwd)"/stacks
