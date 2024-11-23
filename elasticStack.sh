#!/bin/bash
sudo systemctl restart elasticsearch.service kibana.service;
sudo /usr/share/logstash/bin/logstash -f  /etc/logstash/conf.d/pip.conf --path.settings /etc/logstash;
