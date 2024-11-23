alert_THRESHOLD=3  # Définir le seuil pour les tentatives de force brute
elastic_URL="https://node1.elastic.test.com:9200"
#ca_CERT=/etc/elasticsearch/certs/ca.crt
elastic_USER=elastic
elastic_PWD=147896325

check_brute_force_user() {
    # Effectuer la requête pour obtenir les utilisateurs avec des tentatives de connexion échouées
    		#--cacert $ca_CERT pour ajouter la vérification TLS
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
        USER=$(echo $user_info | jq -r '.key' | sed 's/"/\\"/g')  # Pour échapper les guillemets dans le format JSON
        SERVICE=$(echo $user_info | jq -r '.targeted_services.buckets[0].key' | sed 's/"/\\"/g')  # Service le plus ciblé
        # Envoyer l'alerte à Slack
        /home/omar/elastic-config-backup/alerting/send_slack_alert.sh "Possible attaque de force brute ciblant l'utilisateur $USER sur le service $SERVICE"
    done
}

check_brute_force_user

