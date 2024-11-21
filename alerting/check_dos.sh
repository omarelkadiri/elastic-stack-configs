alert_THRESHOLD=100
elastic_URL="https://node1.elastic.test.com:9200"
#ca_CERT=/etc/elasticsearch/certs/ca.crt
elastic_USER=elastic
elastic_PWD=789632145


check_dos() {
    # Effectuer la requête pour obtenir les 10 IP les plus fréquentes
    response=$(curl -u $elastic_USER:$elastic_PWD -X GET "$elastic_URL/network-logs-*/_search" -H 'Content-Type: application/json' -d'{
        "size": 0,
        "query": {
            "bool": {
                "must": [
                    {
                        "exists": {
                            "field": "network.type"
                        }
                    },
                    {
                        "range": {
                            "@timestamp": {
                                "gte": "now-2m",
                                "lte": "now"
                            }
                        }
                    }
                ]
            }
        },
        "aggs": {
            "ip_count": {
                "terms": {
                    "field": "source.ip",
                    "size": 10
                },
                "aggs": {
                    "request_count": {
                        "value_count": {
                            "field": "source.ip"
                        }
                    }
                }
            }
        }
    }')


    # Extraction du nombre de requêtes par IP et analyse
    echo "$response" | jq '.aggregations.ip_count.buckets[] | select(.doc_count > '$alert_THRESHOLD') | .key' | while read ip; do
        IP=$(echo $ip | sed 's/"/\\"/g')  # pour échaper les guillemets (ils font des problèmes avec le formats Json)
        # echo "Possible DoS/DDoS attack from IP: $IP"
        /etc/kibana/alert_slack.sh "Possible DoS/DDoS attack from IP: $IP"
    done
}

check_dos
