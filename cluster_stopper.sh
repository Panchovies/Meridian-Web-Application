#!/bin/bash

kubectl delete svc meridian-web-application -n default
  
eksctl delete cluster meridian-cluster