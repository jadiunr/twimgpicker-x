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