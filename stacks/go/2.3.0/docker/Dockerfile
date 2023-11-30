FROM registry.access.redhat.com/ubi9/go-toolset:1.20.10-2.1699551725

COPY go.mod ./
RUN go mod download

COPY *.go ./

RUN go build -o ./main

EXPOSE 8081

CMD [ "./main" , "-p=8081"]