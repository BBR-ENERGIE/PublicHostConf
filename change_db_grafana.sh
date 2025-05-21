#!/bin/bash

# 🔧 Configuration
VOLUME_PATH="/var/lib/docker/volumes/v_grafana/_data"
DB_SOURCE="/root/grafana/backup/_data/grafana.db"
CONTAINER_NAME="c_grafana"

# 📦 Vérifie que le fichier DB existe
if [ ! -f "$DB_SOURCE" ]; then
    echo "❌ Fichier '$DB_SOURCE' introuvable. Placez le fichier dans le même dossier que ce script."
    exit 1
fi

# ⚠️ Vérification de droits
if [ "$EUID" -ne 0 ]; then
    echo "❌ Veuillez exécuter ce script avec sudo (droits root)."
    exit 1
fi

# 🛑 Stoppe le conteneur
echo "⏳ Arrêt du conteneur Docker '$CONTAINER_NAME'..."
docker stop "$CONTAINER_NAME"
cp "$DB_SOURCE" "$VOLUME_PATH/grafana.db"

# ▶️ Redémarre le conteneur
echo "▶️ Redémarrage du conteneur '$CONTAINER_NAME'..."
docker start "$CONTAINER_NAME"
