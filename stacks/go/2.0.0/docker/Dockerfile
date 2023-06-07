FROM registry.access.redhat.com/ubi9/go-toolset:1.18.10-4

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY *.go ./

RUN go build -o ./main

EXPOSE 8081

CMD [ "app/main" , "-p=8081"]
