#!/bin/bash
docker stop grafana
mkdir -p /root/grafana/backup/
rsync -a /var/lib/docker/volumes/v_grafana/_data/ /root/grafana/backup/
docker start grafana
zenity --info --text="✅ Sauvegarde terminée."
