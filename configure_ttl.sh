#!/bin/bash

# Variables
PROJECT_ID=$1
COLLECTION_ID=$2
FIELD_ID=$3
TTL_DURATION=$4

# Installer le composant alpha si nécessaire
gcloud components install alpha -q

# Configurer TTL pour la collection
gcloud firestore fields ttls update --project=${PROJECT_ID} \
  --collection-group=${COLLECTION_ID} \
  --field-path=${FIELD_ID} \
  --ttl-duration=${TTL_DURATION}