#!/bin/bash
########### Simple script which will find all postgres container and call backup script for each. #########
kubectl describe pods|grep Name:|grep db|sed -E 's/Name:[[:space:]]+//'>details.txt
if [ $? -eq 0 ];then
  {
        while read CONTAINER_NAME; do
        echo "Calling backup script for $CONTAINER_NAME conatiner"
        HOST_IP=$(kubectl describe pod $CONTAINER_NAME|grep IP:|sed -E 's/IP:[[:space:]]+//')
        if [ "x$HOST_IP" = "x" ]; then
        declare HOST_IP="${HOST_IP:-localhost}";
        fi
        HOST_PORT=$(kubectl describe pod $CONTAINER_NAME|grep Port:|tr -c -d 0-9)
        if [ "x$HOST_PORT" = "x" ]; then
        declare HOST_PORT="${HOST_PORT:-5432}";
        fi

        bash /PgBackup/v1-backup-restore.sh -i $HOST_IP -p $HOST_PORT -c $CONTAINER_NAME -a backup
        done <details.txt
}
else
   printf >&2 "\033[1;31mCRITICAL : unable to get information of postgres containers\033[0m\n"
   exit 1
fi