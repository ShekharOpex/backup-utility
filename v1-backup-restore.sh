#!/bin/bash
########### Script to backup and restore postgres data #########

usage(){
	USAGE=$(cat <<-END
	${bold}OPTIONS${normal}:
	           [-b (mandatory) : Back up of postgres database.]
	           [-r (mandatory) : Restore the postgres database.(For restoring you must shutdown all services which contains lock on
	                  postgres database.)]
	           [-h (help): Displays this usage.]
	
	           Example: $0 -b (for backup)
	                    $0 -r (for restore)
	END
	)
	echo -e "$USAGE"
}

### Variables ###
declare HOME_DIR="${HOME_DIR:-/PgBackup}"
declare WORK_DIR="${WORK_DIR:-/HostPgBackup}"
declare BACKUP_FILE="${BACKUP_FILE:-postgres_backup.sql}"
declare BACKUP_FILE_IN_WORK_DIR=$WORK_DIR/$BACKUP_FILE

declare DATA_DUMP_FILE="${DATA_DUMP_FILE:-dump_`date +%d-%m-%Y"_"%H_%M_%S`.sql}"
declare DATA_DUMP_FILE_IN_WORK_DIR=$WORK_DIR/$DATA_DUMP_FILE

declare GPG_BACKUP_PUBLIC_KEY_NAME="IaPgSqlBackupKey1"
declare GPG_BACKUP_PUBLIC_KEY_FILE="IaPgSqlBackupKey1.key"

declare S3_FILE="${S3_FILE:-postgres_backup.s3.`date +%s`}"

if [ "x$POSTGRES_HOST" = "x" ]; then
	declare POSTGRES_HOST="${POSTGRES_HOST:-localhost}";
fi
if [ "x$POSTGRES_PORT" = "x" ]; then
	declare POSTGRES_PORT="${POSTGRES_PORT:-5432}";
fi
if [ "x$POSTGRES_USER" = "x" ]; then
	declare POSTGRES_USER="${POSTGRES_USER:-postgres}"; 
fi
if [ "x$POSTGRES_PWD" = "x" ]; then
	declare POSTGRES_PWD="${POSTGRES_PWD:-postgres}"; 
fi

echo
echo "Postgres uri - $POSTGRES_HOST:$POSTGRES_PORT"
echo

POSTGRES_BACKUP_PARAMS="-h $POSTGRES_HOST -p $POSTGRES_PORT -c -U $POSTGRES_USER"
POSTGRES_RESTORE_PARAMS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -f"
POSTGRES_BACKUP_CLI="pg_dumpall $POSTGRES_BACKUP_PARAMS"
POSTGRES_RESTORE_CLI="psql $POSTGRES_RESTORE_PARAMS" 

if [ "x$AWS_S3_CONFIG_BUCKET" = "x" ]; then AWS_S3_CONFIG_BUCKET="infra-auto/config-data/postgres"; fi
echo "Using AWS S3 bucket : $AWS_S3_CONFIG_BUCKET"
#############

### Find the last updated file and download from S3 bucket
downloadFromS3() {
  latest_file=`aws s3 ls s3://$AWS_S3_CONFIG_BUCKET/ | grep tar | sort | tail -n 1 | awk '{print $4}' | cut -d'/' -f2`
  aws s3 cp s3://$AWS_S3_CONFIG_BUCKET/$latest_file $WORK_DIR/$latest_file
  if [ $? == 0 ]; then
    tar -xvf $WORK_DIR/$latest_file
    rm -f $WORK_DIR/$latest_file
  fi
}


cleanUp() {
  echo "Cleaning up"
  if [ -e $WORK_DIR/$S3_FILE.tar ]; then rm -r $WORK_DIR/$S3_FILE.tar; fi
  if [ -e $WORK_DIR/$DATA_DUMP_FILE ]; then rm -r $WORK_DIR/$DATA_DUMP_FILE; fi
  if [ -e $WORK_DIR/$BACKUP_FILE ]; then rm -r $WORK_DIR/$BACKUP_FILE; fi
}

uploadToS3() {
  #cp $WORK_DIR/$DATA_DUMP_FILE $WORK_DIR/$BACKUP_FILE

  #tar -C $WORK_DIR -cvf $WORK_DIR/$S3_FILE.tar $BACKUP_FILE
  aws s3 cp $DATA_DUMP_FILE_IN_WORK_DIR.asc s3://$AWS_S3_CONFIG_BUCKET/$DATA_DUMP_FILE.asc
}

########### Start backup of postgres ############
backup() {
	
	printVariableValues
	
	createDumpFileInWorkDirectory
	
	encryptAndSignDumpFile

	uploadToS3
	
	#cleanUp
	
	echo
	echo "Done!!!"
}

printVariableValues(){
	echo "Dumping live postgres data using following options values..."
	echo "Work directory - $WORK_DIR"
	echo "Backup file - $BACKUP_FILE"
	echo "Data dump file - $DATA_DUMP_FILE_IN_WORK_DIR"
	echo "PostgreSql host - $POSTGRES_HOST"
	echo "PostgreSql port - $POSTGRES_PORT"
	echo "PostgreSql user - $POSTGRES_USER"
	# we want to avoid show the password on command line 
	#echo "PostgreSql key - $POSTGRES_PWD"
}

createDumpFileInWorkDirectory(){
	PGPASSWORD=$POSTGRES_PWD $POSTGRES_BACKUP_CLI > $DATA_DUMP_FILE_IN_WORK_DIR
	
	#touch $DATA_DUMP_FILE_IN_WORK_DIR
	#echo "Encrypt this file" >> $DATA_DUMP_FILE_IN_WORK_DIR
}

encryptAndSignDumpFile(){
	gpg2 --list-keys $GPG_BACKUP_PUBLIC_KEY_NAME
	
	if [ $? == 0 ]
	then
		echo
		echo 'Key present.'
	else
		echo
   		echo 'Key not present. Try and import the key.'
   		gpg2 --import $HOME_DIR/$GPG_BACKUP_PUBLIC_KEY_FILE
   		if [ $? == 0 ]
   		then
	   		expect <<-EOD
			spawn gpg2 --edit-key $GPG_BACKUP_PUBLIC_KEY_NAME trust quit
			expect "Your decision?"
			send "m\r"
			expect "Do you really want to set this key to ultimate trust? (y/N)"
			send "y\r"
			expect eof
			EOD
		else
			echo
			echo "Unable to find key at $HOME_DIR/$GPG_BACKUP_PUBLIC_KEY_FILE"
		fi
	fi
	
	expect <<-EOD
		spawn gpg2 -u $GPG_BACKUP_PUBLIC_KEY_NAME -r $GPG_BACKUP_PUBLIC_KEY_NAME --armor --encrypt $DATA_DUMP_FILE_IN_WORK_DIR
		expect "Use this key anyway? (y/N)"
		send "y\r"
		expect eof
	EOD
}

#########Restoring the data from s3 buckets#### 
restore() {

			latest_file=`aws s3 ls s3://$AWS_S3_CONFIG_BUCKET/ | grep asc | sort | tail -n 1 | awk '{print $4}' | cut -d'/' -f2`
	  		aws s3 cp s3://$AWS_S3_CONFIG_BUCKET/$latest_file $WORK_DIR/$latest_file
	  		if [ $? -ne 0 ]; then
	    		printf >&2 "\033[1;31mCRITICAL : Download backfile from s3 bucket  Failed\033[0m\n"
	  		fi 
	 		 #decription of a file needs to be done here. encrypted file can be access using $WORK_DIR/$latest_file
			#Below command will might be change depends on decription part. 
			#PGPASSWORD=$POSTGRES_PWD $POSTGRES_RESTORE_CLI $WORK_DIR/$latest_file
  			echo "Done!!!"

}

#################
while getopts ":brh" opt
do
	case ${opt} in
		b) backup exit 1 ;;
		r) restore exit 1 ;;
		h) usage  exit 1 ;;
		\?) usage exit 1 ;;
   esac
done

# if no parameter passed print guide and exit
if [ "$#" -eq "0" ]; then
	#echo -e ${red}'ERROR : Insufficient parameters ! \n'${reset}
	usage
	#exit 1		# not sure why this is exiting the container also. need to fix this issue before raising the PR
fi
############
