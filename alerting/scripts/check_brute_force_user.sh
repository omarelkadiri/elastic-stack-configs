#!/bin/bash

alert_THRESHOLD=3  # Définir le seuil pour les tentatives de force brute
elastic_URL="https://node1.elastic.test.com:9200"
elastic_USER=elastic
elastic_PWD=147896325

# Répertoire pour les sauvegardes
LOG_DIR="/home/omar/alerting/logs/check_brute_force_logs"
mkdir -p "$LOG_DIR"

# Fichier log pour la journée en cours
LOG_FILE="$LOG_DIR/brute_force_alerts_$(date +'%Y-%m-%d').log"

check_brute_force_user() {
    # Effectuer la requête pour obtenir les utilisateurs avec des tentatives de connexion échouées
    response=$(curl -u $elastic_USER:$elastic_PWD -k -X GET "$elastic_URL/network-logs-syslog-auth-*/_search" -H 'Content-Type: application/json' -d'{
      "size": 0,
      "query": {
        "bool": {
          "must": [
            {
              "term": {
                "auth.result.keyword": "could not authenticate"
              }
            },
            {
              "range": {
                "@timestamp": {
                  "gte": "now-1m",
                  "lte": "now"
                }
              }
            }
          ]
        }
      },
      "aggs": {
        "failed_user_count": {
          "terms": {
            "field": "auth.user.keyword",
            "size": 10
          },
          "aggs": {
            "targeted_services": {
              "terms": {
                "field": "auth.service.keyword",
                "size": 1
              }
            }
          }
        }
      }
    }')

    # Nettoyer la réponse JSON pour enlever les caractères de contrôle
    clean_response=$(echo "$response" | sed 's/[\x00-\x1F]//g')

    # Extraire le nombre de tentatives échouées par utilisateur et analyser
    echo "$clean_response" | jq -c '.aggregations.failed_user_count.buckets[] | select(.doc_count > '$alert_THRESHOLD')' | while read user_info; do
        USER=$(echo $user_info | jq -r '.key' | sed 's/"/\\"/g')  # Nom d'utilisateur ciblé
        SERVICE=$(echo $user_info | jq -r '.targeted_services.buckets[0].key' | sed 's/"/\\"/g')  # Service ciblé
        ATTEMPTS=$(echo $user_info | jq -r '.doc_count')  # Nombre de tentatives échouées

        # Construire le message d'alerte pour Slack
        ALERT_MESSAGE=$(printf "Possible attaque de force brute : utilisateur %s, service %s, tentatives %d" "$USER" "$SERVICE" "$ATTEMPTS")
        /home/omar/alerting/scripts/send_slack_alert.sh "$ALERT_MESSAGE"

        # Sauvegarder l'alerte dans un fichier log
        ALERT_LOG=$(printf '{"timestamp":"%s","user":"%s","service":"%s","attempts":%d}\n' "$(date +'%Y-%m-%dT%H:%M:%S')" "$USER" "$SERVICE" "$ATTEMPTS")
        echo "$ALERT_LOG" >> "$LOG_FILE"
    done
}

check_brute_force_user

