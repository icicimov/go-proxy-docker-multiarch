FROM golang:1.10 AS build-env

WORKDIR /go/src/app

COPY *.go /go/src/app/

ARG GOLDFLAGS="-w -s -extldflags \"-static\""
ARG CGO_ENABLED=0
#ENV CGO_ENABLED=$CGO_ENABLED
ARG GOOS=linux
#ENV GOOS=$GOOS
ARG GOARCH=amd64
#ENV GOARCH=$GOARCH

RUN CGO_ENABLED=$CGO_ENABLED GOOS=$GOOS GOARCH=$GOARCH go build -a -ldflags \'"${GOLDFLAGS}"\' -installsuffix cgo -o goserver .

FROM alpine

#ADD ca-certificates.crt /etc/ssl/certs/
RUN apk --no-cache add --update ca-certificates \
 && rm -rf /var/cache/apk/*

COPY --from=build-env /go/src/app/goserver /app/

ARG PORT
ENV PORT ${PORT:-8989}

# Run as non root user
RUN addgroup -g 10001 -S app && \
    adduser -u 10001 -S app -G app 
USER app

EXPOSE ${PORT}

CMD ["/app/goserver"]