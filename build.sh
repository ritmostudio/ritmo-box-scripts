# build and push node player image
echo "🔨 Building lucassaid/ritmo-node-player"
cd ../node-player
npm run build
docker build \
    --build-arg NPM_TOKEN=$NPM_TOKEN \
    -t lucassaid/ritmo-node-player \
    .
echo "⬆️ Pushing lucassaid/ritmo-node-player"
docker image push lucassaid/ritmo-node-player

# build and push box UI image
echo "🔨 Building lucassaid/ritmo-box-ui"
cd ../ritmo-box-ui
npm run build
docker build \
    --build-arg NPM_TOKEN=$NPM_TOKEN \
    -t lucassaid/ritmo-box-ui \
    .
echo "⬆️ Pushing lucassaid/ritmo-box-ui"
docker image push lucassaid/ritmo-box-ui

# build and push pulseaudio image
echo "🔨 Building lucassaid/ritmo-pulseaudio"
cd ../audio
docker build \
    -t lucassaid/ritmo-audio \
    .

echo "⬆️ Pushing lucassaid/ritmo-audio"
docker image push lucassaid/ritmo-audio
