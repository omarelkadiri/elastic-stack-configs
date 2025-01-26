# Importer la Dashboard et les Visualisations Kibana

## Prérequis

- Un serveur Kibana opérationnel (par défaut sur `http://localhost:5601`)
- Les fichiers d'export :
  - `Dashboard_SIEM.ndjson` (Dashboards Kibana)
  - `Visualisations.ndjson` (Visualisations Kibana)

### Cloner le dépôt contenant les fichiers d'export

```bash
git clone https://github.com/omarelkadiri/elastic-stack-configs
cd elastic-stack-configs/kibana-config
```

## Importer dans Kibana via l'API

```bash
curl -X POST "http://localhost:5601/api/saved_objects/_import" -H "kbn-xsrf: true" --form file=@Dashboard_SIEM.ndjson
curl -X POST "http://localhost:5601/api/saved_objects/_import" -H "kbn-xsrf: true" --form file=@Visualisations.ndjson
```

## Problèmes courants et solutions

### Erreur 413 - Payload Too Large

Si vous recevez une erreur `413 Payload Too Large`, augmentez la taille maximale des requêtes dans `kibana.yml` :

```yaml
server.maxPayload: 104857600
```

Puis redémarrez Kibana :

```bash
systemctl restart kibana
```

## Vérification

1. Accédez à Kibana.
2. Allez dans **Stack Management > Saved Objects**.
3. Assurez-vous que les objets ont bien été importés.
4. Ouvrez **Dashboard** dans Kibana pour voir vos données.  
   ⚠️ **Les index utilisés par les visualisations doivent exister et contenir des données compatibles**.

