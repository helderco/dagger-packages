package app

PostgreSQL: _BitnamiPostgreSQL

_BitnamiPostgreSQL: _PostgreSQL & {
	create_db: string
	init_dir: string
	services: db: {
		image: "bitnami/postgresql:12.10.0-debian-10-37"
		environment: {
			POSTGRESQL_TIMEZONE: "Atlantic/Azores"
			POSTGRESQL_LOG_TIMEZONE: POSTGRESQL_TIMEZONE
			POSTGRESQL_POSTGRES_PASSWORD_FILE: "/var/secrets/root_password"
			if create_db != _|_ {
				POSTGRESQL_DATABASE: create_db
				POSTGRESQL_USERNAME: create_db
				POSTGRESQL_PASSWORD_FILE: "/var/secrets/user_password"
			}
		}
		if init_dir != _|_ {
			volumes: {
				"\(init_dir)": "/docker-entrypoint-initdb.d"
			}
		}
	}
}

_PostgreSQL: {
	port: string | *"5432"
	S=secrets: [string]: _
	services: db: {
		ports: [
			"127.0.0.1:\(port):5432",
		]
		secrets: {
			for secret_name, _ in S {
				"\(secret_name)": _
			}
		}
	}
}
