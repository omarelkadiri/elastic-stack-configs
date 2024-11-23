#!/bin/bash
message="$1"
send_slack_alert() {
    local slack_webhook_url="https://hooks.slack.com/services/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" # URL Webhook Slack

    # Structure du message au format JSON
    payload=$(cat <<EOF
{
    "text": "$message"
}
EOF
)
    echo "Payload envoyé : $payload" # Log du payload pour vérifier    
# Envoi de la requête à Slack
    curl -X POST -H 'Content-type: application/json' \
    --data "$payload" \
    "$slack_webhook_url"
}
send_slack_alert
