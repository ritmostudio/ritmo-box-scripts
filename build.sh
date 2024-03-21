# build and push node player image
cd ../node-player
npm run build
docker build \
    --build-arg NPM_TOKEN=$NPM_TOKEN \
    -t lucassaid/ritmo-node-player:latest \
    .
docker image push lucassaid/ritmo-node-player:latest

# build and push box UI image
cd ../ritmo-box-ui
npm run build
docker build \
    --build-arg NPM_TOKEN=$NPM_TOKEN \
    -t lucassaid/ritmo-box-ui:latest \
    .
docker image push lucassaid/ritmo-box-ui:latest
