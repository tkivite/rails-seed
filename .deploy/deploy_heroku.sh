#!/bin/sh

docker pull $HEROKU_REGISTRY_IMAGE
HEROKU_IMAGE_ID=$(docker inspect ${HEROKU_REGISTRY_IMAGE} --format={{.Id}})

curl --location --request PATCH "https://api.heroku.com/apps/${HEROKU_APP_NAME}/formation" \
--header "Authorization: Bearer ${HEROKU_TOKEN}" \
--header "Accept: application/vnd.heroku+json; version=3.docker-releases" \
--header "Content-Type: application/json" \
--data-raw '{ 
                        "updates": [ { 
                                        "type": "web", 
                                        "docker_image": "'$HEROKU_IMAGE_ID'" 
                                      } 
                                    ] 
                      }'