package app

MySQL: _BitnamiMySQL

_BitnamiMySQL: _MySQL & {
	data_dest: "/bitnami/mysql/data"
	conf_dest: "/opt/bitnami/mysql/conf/my_custom.cnf"
	create_db: string
	init_dir: string
	secrets: _
	services: db: {
		image: "bitnami/mysql:8.0.28-debian-10-r44"
		environment: {
		    MYSQL_CHARACTER_SET: "utf8mb4"
    		MYSQL_COLLATE: "utf8mb4_unicode_ci"
			MYSQL_AUTHENTICATION_PLUGIN: "mysql_native_password"
			MYSQL_ROOT_PASSWORD_FILE: "/var/secrets/root_password"
			if create_db != _|_ {
				MYSQL_DATABASE: create_db
				MYSQL_USER: create_db
				MYSQL_PASSWORD_FILE: "/var/secrets/user_password"
			}
		}
		if init_dir != _|_ {
			volumes: {
				"\(init_dir)": "/docker-entrypoint-initdb.d"
			}
		}
		healthcheck: {
			test: ["CMD", "/opt/bitnami/scripts/mysql/healthcheck.sh"]
			interval: "15s"
			timeout: "5s"
			retries: 6
		}
	}
}

_MySQL: {
	port: string | *"3306"
	backups_dir: string
	data_dest: string
	conf_dest: string
	conf?: string
	S=secrets: [string]: _

	services: db: {
		ports: [
			"127.0.0.1:\(port):3306",
		]
		configs: {
			if conf != _|_ {
				my: target: conf_dest
			}
			backup: {
				target: "/usr/local/bin/backup"
				mode: 0o550
			}
		}
		volumes: {
			data: data_dest
			"\(backups_dir)": "/backups"
		}
		secrets: {
			for secret_name, _ in S {
				"\(secret_name)": _
			}
		}
	}

	if conf != _|_ {
		configs: my: {
			file: "./my.cnf"
			contents: conf
			mode: 0o440
		}
	}

	configs: backup: {
		file: "./backup.sh"
		contents: #"""
			#!/bin/bash

			set -euxo pipefail

			export MYSQL_PWD=$(cat /run/secrets/root_password)

			# Backup Dest directory, change this if you have some other location
			DEST="/backups"

			MyUID=$(stat -c '%u' $DEST)
			MyGID=$(stat -c '%g' $DEST)

			# Main directory where backup will be stored
			MBD="$DEST/db"

			# Incremental backups
			INC="$DEST/inc"

			# Make sure destination exists
			mkdir -p $MBD
			mkdir -p $INC

			# Get week
			WEEK="$(date +"%w")"

			# DO NOT BACKUP these databases
			declare -a IGGY=(information_schema performance_schema mysql sys)

			# Get all database list first
			DBS=$(mysql -u root -Bse "show databases")

			ignore() {
				for i in ${IGGY[@]}; do
					if [[ ${i} == ${1} ]]; then
						return 0
					fi
				done
				return 1
			}

			for db in $DBS; do
				ignore $db || {
					FILE="$MBD/$db.sql.gz"
					INC_FILE="$INC/$db.$WEEK.sql.gz"

					mysqldump -u root $db | gzip --best  > $FILE
					chown $MyUID:$MyGID $FILE

					cp -a $FILE $INC_FILE
				}
			done

			"""#
	}

	volumes: data: _
}
