#!/bin/bash

mkdir -p /var/lib/docker/volumes/v_grafana/_data
cp /root/grafana/backup/grafana.db /var/lib/docker/volumes/v_grafana/_data/grafana.db
docker restart c_grafana
