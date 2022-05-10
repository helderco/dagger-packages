package app

Django: {
	project: _
	D=domain: string
	I=image: string
	E=environment: [string]: string
	// S=secrets: [string]: _
	services: {
		uwsgi: {
			image: I
			traefik: {
				domain: D
				port: 9000
			}
			networks: {
				ingress: _
				postgres: _
			}
			environment: {
				E
				POSTGRESQL_HOST: string | *"db"
				POSTGRESQL_DATABASE: project
				POSTGRESQL_USERNAME: project
				DJANGO_SETTINGS_MODULE: "confs.settings.prod"
				DEFAULT_FROM_EMAIL: "info@mg.\(domain)"
				EMAIL_HOST: "smtp.mailgun.org"
				EMAIL_HOST_USER: "postmaster@mg.\(domain)"
				EMAIL_PORT: "587"
				EMAIL_USE_TLS: "True"
			}
			// secrets: {
			// 	for secret_name, _ in S {
			// 		"\(secret_name)": _
			// 	}
			// }
			volumes: media: "/app/public/media"
		}
	}
	volumes: media: _
}
