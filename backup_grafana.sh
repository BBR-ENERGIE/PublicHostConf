#!/bin/bash
docker stop c_grafana
mkdir -p /root/grafana/backup/
rsync -a /var/lib/docker/volumes/v_grafana/_data/ /root/grafana/backup/
docker start c_grafana
