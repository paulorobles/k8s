#!/bin/bash
sudo ufw status verbose
sudo ufw allow 22
sudo ufw allow 2222
sudo ufw allow 6443/tpc
sudo ufw allow 2379:2380/tpc
sudo ufw allow 10250:10252/tpc
sudo ufw allow 10255/tpc
sudo ufw enable