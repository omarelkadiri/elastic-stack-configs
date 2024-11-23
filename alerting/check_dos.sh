alert_THRESHOLD=10
elastic_URL="https://node1.elastic.test.com:9200"
elastic_USER=elastic
elastic_PWD=147896325

check_dos() {
    response=$(curl -u $elastic_USER:$elastic_PWD -k -X POST "$elastic_URL/network-logs-syslog-*/_search" -H 'Content-Type: application/json' -d'
    {
        "size": 0,
        "query": {
            "range": {
                "@timestamp": {
                    "gte": "now-1m", 
                    "lte": "now"
                }
            }
        },
        "aggs": {
            "targeted_ips": {
                "terms": {
                    "field": "destination.ip",
                    "size": 10
                },
                "aggs": {
                    "top_attackers": {
                        "terms": {
                            "field": "source.ip",
                            "size": 10
                        }
                    }
                }
            }
        }
    }')

    # Nettoyer la réponse JSON pour enlever les caractères de contrôle
    clean_response=$(echo "$response" | sed 's/[\x00-\x1F]//g')

    # Parcourir les adresses IP ciblées
    echo "$clean_response" | jq -c '.aggregations.targeted_ips.buckets[] | select(.doc_count > '$alert_THRESHOLD')' | while read target_info; do
        TARGET_IP=$(echo $target_info | jq -r '.key')  # Adresse IP cible
        TOTAL_PACKETS=$(echo $target_info | jq -r '.doc_count')  # Nombre total de paquets vers la cible
        
        # Construire la liste des attaquants
        ATTACKERS=$(echo $target_info | jq -c '.top_attackers.buckets[] | "\(.key) (\(.doc_count) paquets)"' | paste -sd ', ' -)
        
        # Échapper les caractères spéciaux pour Slack
        SAFE_MESSAGE=$(printf "Cible : %s subissant une possible attaque DoS/DDoS avec %s paquets. Sources : %s" "$TARGET_IP" "$TOTAL_PACKETS" "$ATTACKERS" | sed 's/"/\\"/g')

        # Envoyer l'alerte à Slack
        PAYLOAD=$SAFE_MESSAGE
        /home/omar/elastic-config-backup/alerting/send_slack_alert.sh "$PAYLOAD"
    done
}

check_dos

