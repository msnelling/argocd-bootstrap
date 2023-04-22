#!/bin/bash
set -ex

BACKUP_DIR='/Users/mark/Downloads'
BACKUP_FILE='gitlab_backup.tar'
NAMESPACE='gitlab'

TASKRUNNER_POD=$(kubectl get pods -lrelease=gitlab,app=toolbox -n $NAMESPACE -ojsonpath='{.items[0].metadata.name}')
kubectl cp $BACKUP_DIR/$BACKUP_FILE $NAMESPACE/$TASKRUNNER_POD:/tmp/gitlab_backup.tar
kubectl exec -n $NAMESPACE $TASKRUNNER_POD -it -- backup-utility --restore -f file:///tmp/gitlab_backup.tar
