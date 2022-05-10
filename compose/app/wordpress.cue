package app

Wordpress: Php74 & {
    services: web: {
        image: "bitnami/nginx:1.21.6-debian-10-r51"
        configs: nginx: target: "/opt/bitnami/nginx/conf/server_blocks/wordpress.conf"
    }
    configs: nginx: {
        file: "./nginx.conf"
        contents: #"""
            server {
                listen 0.0.0.0:8080;
                server_name _;

                root /app;
                index index.html index.html index.php

                location / {
                    try_files $uri $uri/index.php;
                }

                location ~ \.php$ {
                    # fastcgi_pass [PHP_FPM_LINK_NAME]:9000;
                    fastcgi_pass phpfpm:9000;
                    fastcgi_index index.php;
                    include fastcgi.conf;
                }
            }

            """#
    }
}

Php74: Php & {
    services: app: image: "bitnami/php-fpm:7.4.28-debian-10-r33"
}

Php: {
    project: _
    D=domain: _
    // S=secrets: [string]: _
    hostDir: string
    root_dir: string | *"\(hostDir)/sites/\(project)"
    shared_volume: {
        source: string | *root_dir
        dest: string | *"/app"
    }
    services: {
        web: {
            traefik: domain: D
            networks: {
                default: _
                ingress: _
            }
            volumes: "\(shared_volume.source)": "\(shared_volume.dest)"
            depends_on: ["app"]
        }
        app: {
            container_name: project
            networks: {
                default: _
                mysql: _
            }
            volumes: "\(shared_volume.source)": "\(shared_volume.dest)"
            environment: {
                MYSQL_HOST: string | *"db"
                MYSQL_DATABASE: string | *project
                MYSQL_USER: string | *project
            }
			// secrets: {
			// 	for secret_name, _ in S {
			// 		"\(secret_name)": _
			// 	}
			// }
        }
    }
}
