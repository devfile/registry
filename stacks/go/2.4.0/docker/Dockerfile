FROM registry.access.redhat.com/ubi9/go-toolset:1.21.9-1.1714671022

COPY go.mod ./
RUN go mod download

COPY *.go ./

RUN go build -o ./main

EXPOSE 8081

CMD [ "./main" , "-p=8081"]
