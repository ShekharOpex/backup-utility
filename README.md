# Backup utility


This service use to take a backup of postgres docker container and upload it to S3 bucket.It is largely subject to change.

## Reference

## Development

### Running locally from the project directory

There are a few external dependencies to be aware of when running the service . Your postgres container should be running in the same enviornment.
to build the image use
$ docker build -t  docker-dev-local.intelliclouddev.com/ia/ia-postgres-data-handler:0.0.1 . -f BackupContainerDockerFile

you have to provide the below enviornment variables while running the service.

$ docker run -d --name ia-postgres-data-handler -v ~/HostPgBackup:/HostPgBackup:rw -e AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXX -e AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXX -e AWS_DEFAULT_REGION=XXXXXXXXXXXXXXX -e AWS_S3_CONFIG_BUCKET=infra-auto/config-data/postgres -e POSTGRES_HOST=172.17.0.3 -e POSTGRES_PORT=5432 -e POSTGRES-USER=postgres -e POSTGRES_PASSWORD=postgres docker-dev-local.intelliclouddev.com/ia/ia-postgres-data-handler:0.0.1

For POSTGRES_HOST=172.17.0.3 , do check IP of your postgres container by $ docker inspect <postgres container id > if it is not 172.17.0.3  then replace this with your IP. 

#IMPORTANT NOTE
we are assuming that pgsql binaries will be available on the server, for testing this service on your local machine you need to add those binaries in your files folder .

