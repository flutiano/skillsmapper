### Firestore setup ###
gcloud config set project $PROJECT_ID
gcloud services enable firestore.googleapis.com

gcloud alpha firestore databases create --location=$REGION --type=firestore-native

### Configuring Pub/Sub ###
gcloud services enable pubsub.googleapis.com

gcloud pubsub topics create $FACT_CHANGED_TOPIC
gcloud pubsub topics create $FACT_CHANGED_TOPIC-deadletter

### Service accounts ###
gcloud pubsub topics add-iam-policy-binding ${FACT_CHANGED_TOPIC} \
  --member=serviceAccount:${FACT_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/pubsub.publisher

export PROFILE_SERVICE_SA=profile-service-sa
gcloud iam service-accounts create $PROFILE_SERVICE_SA \
  --description="${PROFILE_SERVICE_NAME} service account"

# gcloud projects add-iam-policy-binding $PROJECT_ID \
#   --member=serviceAccount:${PROFILE_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
#   --role=roles/pubsub.subscriber

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:${PROFILE_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/logging.logWriter

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:${PROFILE_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/datastore.user

### Deploy profile-service ###
envsubst < env.yaml.template > env.yaml
gcloud run deploy $PROFILE_SERVICE_NAME --source . \
  --env-vars-file env.yaml \
  --service-account $PROFILE_SERVICE_SA@${PROJECT_ID}.iam.gserviceaccount.com \
  --allow-unauthenticated
  --region $REGION

export PROFILE_SERVICE_URL=$(gcloud run services describe $PROFILE_SERVICE_NAME \
--format='value(status.url)' \
--region=$REGION)

### Pub/Sub subscription ###
export FACT_CHANGED_SUBSCRIPTION=fact-changed-subscription
export FACT_CHANGED_SUBSCRIPTION_SA=$FACT_CHANGED_SUBSCRIPTION-sa

gcloud iam service-accounts create $FACT_CHANGED_SUBSCRIPTION_SA \
  --description="${FACT_CHANGED_SUBSCRIPTION} service account" 

gcloud run services add-iam-policy-binding $PROFILE_SERVICE_NAME \
    --member=serviceAccount:${FACT_CHANGED_SUBSCRIPTION_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/run.invoker \
    --region=$REGION

gcloud pubsub subscriptions create $FACT_CHANGED_SUBSCRIPTION \
  --topic $FACT_CHANGED_TOPIC \
  --dead-letter-topic $FACT_CHANGED_TOPIC-deadletter \
  --push-endpoint $PROFILE_SERVICE_URL/factschanged \
  --max-delivery-attempts 5 \
  --push-auth-service-account ${FACT_CHANGED_SUBSCRIPTION_SA}@${PROJECT_ID}.iam.gserviceaccount.com 

# gcloud pubsub subscriptions delete $FACT_CHANGED_SUBSCRIPTION

### Testing the profile service ###
export ID_TOKEN=$(curl "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=${API_KEY}" \
    -H "Content-Type: application/json" \
    --data-binary "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\",\"returnSecureToken\":true}" | jq -r '.idToken')

payload=$(echo $ID_TOKEN | cut -d"." -f2)
decoded=$(echo $payload | base64 -d 2>/dev/null || echo $payload | base64 -di)
export USER_ID=$(echo $decoded | jq -r .user_id)

envsubst < examples/fact-changed.json.template > examples/fact-changed.json
gcloud pubsub topics publish $FACT_CHANGED_TOPIC --message "$(cat examples/fact-changed.json)"

gcloud beta run services logs read $PROFILE_SERVICE_NAME --region $REGION

open "https://console.cloud.google.com/firestore/databases/-default-/data/panel/profiles?project=${PROJECT_ID}"

curl -X GET -H "Authorization: Bearer ${ID_TOKEN}" ${PROFILE_SERVICE_URL}/api/profiles/me