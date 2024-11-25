#!/bin/bash

alert_THRESHOLD=5  # Seuil d'alertes pour les IP bloquées
elastic_URL="https://node1.elastic.test.com:9200"
elastic_USER=elastic
elastic_PWD=147896325

# Répertoire pour les sauvegardes
LOG_DIR="/home/omar/alerting/logs/check_blocked_packets_logs"
mkdir -p "$LOG_DIR"

# Fichier log pour la journée en cours
LOG_FILE="$LOG_DIR/blocked_packets_alerts_$(date +'%Y-%m-%d').log"

check_blocked_packets() {
    # Requête ElasticSearch pour les paquets bloqués
    response=$(curl -u $elastic_USER:$elastic_PWD -k -X POST "$elastic_URL/network-logs-syslog-*/_search" -H 'Content-Type: application/json' -d'
    {
        "size": 0,
        "query": {
            "bool": {
                "must": [
                    {
                        "term": {
                            "event.action.keyword": "block"
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
            "blocked_ips": {
                "terms": {
                    "field": "source.ip",
                    "size": 10
                }
            }
        }
    }')

    # Nettoyer la réponse JSON pour enlever les caractères de contrôle
    clean_response=$(echo "$response" | sed 's/[\x00-\x1F]//g')

    # Parcourir les adresses IP bloquées
    echo "$clean_response" | jq -c '.aggregations.blocked_ips.buckets[] | select(.doc_count > '$alert_THRESHOLD')' | while read blocked_info; do
        BLOCKED_IP=$(echo $blocked_info | jq -r '.key')  # Adresse IP bloquée
        BLOCKED_COUNT=$(echo $blocked_info | jq -r '.doc_count')  # Nombre de paquets bloqués
        
        # Construire le message Slack
        ALERT_MESSAGE=$(printf "Activité suspecte détectée : L'adresse IP %s a été bloquée %d fois au cours de la dernière minute." "$BLOCKED_IP" "$BLOCKED_COUNT")
        /home/omar/alerting/scripts/send_slack_alert.sh "$ALERT_MESSAGE"

        # Sauvegarder l'alerte dans un fichier log
        ALERT_LOG=$(printf '{"timestamp":"%s","blocked_ip":"%s","blocked_count":%d}\n' "$(date +'%Y-%m-%dT%H:%M:%S')" "$BLOCKED_IP" "$BLOCKED_COUNT")
        echo "$ALERT_LOG" >> "$LOG_FILE"
    done
}

# Appeler la fonction pour vérifier les paquets bloqués
check_blocked_packets

