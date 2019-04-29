# twimgpicker-x

Image collection bot for tweets.

## Get started

```
cp settings.yml.sample settings.yml
vim settings.yml
  # consumer_key ~ access_token_secret: Your Twitter API credentials
  # target: Your target Twitter "Screen name" (Not "User ID")
  # outdir: Storage location of the image (default "media")

mkdir media # or ↑ outdir name
docker-compose build
docker-compose run --rm app carton install
docker-compose up -d
```

## Permission problem

Try this ↓
```
cp docker-compose.override.yml.sample docker-compose.override.yml
```

```
$ cat docker-compose.override.yml
version: '2'

services:
  app:
    volumes:
      - /etc/group:/etc/group:ro
      - /etc/passwd:/etc/passwd:ro
    user: '1000:1000' # Replace to your host UID and GID
```