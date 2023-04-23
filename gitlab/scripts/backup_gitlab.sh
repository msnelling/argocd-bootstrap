#!/bin/bash

BACKUP_DIR=/Users/mark/Downloads
BACKUP_FILE=gitlab_backup.tar
NAMESPACE=gitlab

TASKRUNNER_POD=$(kubectl get pods -n $NAMESPACE -lrelease=gitlab,app=toolbox --field-selector=status.phase==Running -o jsonpath="{.items[0].metadata.name}")
echo "Using taskrunner pod $NAMESPACE/$TASKRUNNER_POD"

kubectl exec $TASKRUNNER_POD -it -n $NAMESPACE -- backup-utility --maximum-backups 7
