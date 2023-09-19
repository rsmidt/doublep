# Doublep

Doublep (**P**lanning **P**oker) is a simple Elixir app to allow for setting up quick planning poker
estimation sessions.

## Building & Deployment

We fully utilize Docker to enable quick and easy deployments. You can pull the image from GHCR:

```
docker pull ghcr.io/rsmidt/doublep:main
```

Running it is as simply as providing the required env variables for the PostgreSql connection:

```yaml
version: "3"
services:
  db:
    image: postgres:14
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: <db password>
      POSTGRES_DB: <db user>

  server:
    image: ghcr.io/rsmidt/doublep:main
    restart: unless-stopped
    environment:
      DOUBLEP_PHX_HOST: "<your domain>"
      DOUBLEP_PHX_PORT: 80
      DOUBLEP_PHX_SECRET_KEY_BASE: "<secret key>"
      DOUBLEP_DATABASE_URL: "ecto://<db user>:<db password>@db/doublep"
      # Optionally, enable support for instrumentation.
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4318"
```
