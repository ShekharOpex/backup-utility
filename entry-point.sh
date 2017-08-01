#!/bin/sh
#
touch /PgBackup/cron.log
# Run the data backup/restore script at once startup
/PgBackup/pgBackupForAll.sh > /PgBackup/cron.log 2>&1
# Start the cron job process
crond
tail -f /PgBackup/cron.log
