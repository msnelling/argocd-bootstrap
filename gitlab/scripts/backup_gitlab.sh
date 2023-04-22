#!/bin/bash

TOOLBOX_POD=$(kubectl get pods -n gitlab -lrelease=gitlab,app=toolbox --field-selector=status.phase==Running -o jsonpath="{.items[0].metadata.name}")

kubectl exec $TOOLBOX_POD -it -n gitlab -- backup-utility --maximum-backups 7
