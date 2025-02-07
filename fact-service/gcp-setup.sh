# gcloud services enable sqladmin.googleapis.com

export PROJECT_ID='cnatdev-gcp'
export REGION='asia-northeast3'
export FACT_SERVICE_NAME='fact-service'

export INSTANCE_NAME='facts-instance'
export DATABASE_TIER='db-f1-micro'
export DISK_SIZE=10
export DATABASE_NAME='facts'
export FACT_SERVICE_USER=''
export FACT_SERVICE_PASSWORD=''
export FACT_CHANGED_TOPIC='fact-changed'

### create Cloud SQL instance and database ###
# gcloud sql instances create $INSTANCE_NAME \
#     --database-version=POSTGRES_14 \
#     --tier=$DATABASE_TIER \
#     --region=$REGION \
#     --availability-type=REGIONAL \
#     --storage-size=$DISK_SIZE

# gcloud sql databases create $DATABASE_NAME \
#     --instance=$INSTANCE_NAME

export FACT_SERVICE_DB_USER=''
export FACT_SERVICE_DB_PASSWORD=''

# gcloud sql users create $FACT_SERVICE_DB_USER \
#     --instance=$INSTANCE_NAME \
#     --password=$FACT_SERVICE_DB_PASSWORD

### create Cloud Run service ###
gcloud run deploy ${FACT_SERVICE_NAME} --source . \
--set-env-vars PROJECT_ID=$PROJECT_ID,SERVICE_NAME=$FACT_SERVICE_NAME,SPRING_PROFILES_ACTIVE=h2 \
--allow-unauthenticated

export FACT_SERVICE_URL=$(gcloud run services describe $FACT_SERVICE_NAME --format='value(status.url)')
# curl -X GET ${FACT_SERVICE_URL}/api/facts

### create a db secret ###
# gcloud services enable secretmanager.googleapis.com

export FACT_SERVICE_DB_PASSWORD_SECRET_NAME='fact_service_db_password_secret'

# gcloud secrets create $FACT_SERVICE_DB_PASSWORD_SECRET_NAME \
#     --replication-policy=automatic \
#     --data-file=<(echo -n $FACT_SERVICE_DB_PASSWORD)

### create a service account ###
export FACT_SERVICE_SA='fact-service-sa'
# gcloud iam service-accounts create $FACT_SERVICE_SA \
#     --description="${FACT_SERVICE_NAME} service account"

# gcloud projects add-iam-policy-binding $PROJECT_ID \
#   --member=serviceAccount:${FACT_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
#   --role=roles/cloudsql.client

# gcloud secrets add-iam-policy-binding $FACT_SERVICE_DB_PASSWORD_SECRET_NAME \
#   --member=serviceAccount:${FACT_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
#   --role=roles/secretmanager.secretAccessor

### update fact-service with SA and Cloud SQL instance ###
envsubst < env.yaml.template > env.yaml

# gcloud run services update $FACT_SERVICE_NAME \
#     --service-account ${FACT_SERVICE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
#     --add-cloudsql-instances ${PROJECT_ID}:${REGION}:${INSTANCE_NAME} \
#     --env-vars-file=env.yaml \
#     --update-secrets=DATABASE_PASSWORD=${FACT_SERVICE_DB_PASSWORD_SECRET_NAME}:latest

curl -X GET ${FACT_SERVICE_URL}/api/facts

curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{ "skill": "java", "level": "learning" }`' \
  ${FACT_SERVICE_URL}/api/facts

### set up Auth ###
export API_KEY=''

export ID_TOKEN=$(curl "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=${API_KEY}" \
        -H "Content-Type: application/json" \
        --data-binary "{\"email\":\"${FACT_SERVICE_USER}\",\"password\":\"${FACT_SERVICE_PASSWORD}\",\"returnSecureToken\":true}" \
        | jq -r '.idToken')

curl -X POST \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d '{ "skill": "java", "level": "learning" }`' \
  ${FACT_SERVICE_URL}/api/facts

curl -X GET ${FACT_SERVICE_URL}/api/facts \
  -H "Authorization: Bearer ${ID_TOKEN}"

curl -X DELETE \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  ${FACT_SERVICE_URL}/api/facts/1

### Improve the startup time ###
ab -n 3 -H "Authorization: Bearer ${ID_TOKEN}" ${FACT_SERVICE_URL}/api/facts

gcloud run services update $FACT_SERVICE_NAME \
    --min-instances=1 \
    --max-instances=3
