package app

import (
	"encoding/yaml"
	"list"
	"strings"
	"path"
	"dagger.io/dagger"
	"github.com/helderco/dagger-packages/lib"
	"github.com/helderco/dagger-packages/compose/spec"
)

#ServiceConfigs: [S=string]: {
	source: S
	target?: string
	uid?: string
	gid?: string
	mode?: int
}

#Service: {
	project: string
	configs?: #ServiceConfigs // target defaults to /<source>
	secrets?: #ServiceConfigs // target defaults to <source> -> /run/secrets/<target>
	volumes?: [source=string]: string | *source
	networks?: [string]: null | *{
		aliases?: [...string]
	}
	deploy?: _
	traefik?: {
		https: *true | false
		domain: *null | string
		router: {
			rule: string
			if domain != null {
				rule: "Host(`\(domain)`) || Host(`www.\(domain)`)"
			}
			if https {
				entryPoints: "websecure"
				"tls.certresolver": "le"
			}
			if !https {
				entryPoints: "web"
			}
			let collected = [
				for key, value in middlewares {
					if (value & string) != _|_ {
						"\(key)@\(value)",
					}
					if (value & string) == _|_ {
						"\(project)-\(key)@docker",
					}
				}
			]
			if len(collected) > 0 {
				middlewares: strings.Join(collected, ",")
			}
			...
		}
		if domain != null {
			middlewares: {
				www: redirectregex: {
					regex: "^https?://\(domain)/(.*)$$"
					replacement: "https://www.\(domain)/$${1}"
					permanent: true
				}
			}
		}
		middlewares: [string]: _#dockerMiddleware | *_#externalMiddleware
		_#dockerMiddleware: [string]: {...}
		_#externalMiddleware: string | *"file"
		port: null | int | *8080
	}
	if traefik != _|_ {
		labels: {
			"traefik.enable": true
			for key, value in traefik.router {
				"traefik.http.routers.\(project).\(key)": value
			}
			if traefik.port != null {
				"traefik.http.services.\(project).loadbalancer.server.port": traefik.port
			}
			for key, middlewares in traefik.middlewares {
				if (middlewares & string) == _|_ {
					for middleware, config in middlewares {
						for field, value in config {
							"traefik.http.middlewares.\(project)-\(key).\(middleware).\(field)": "\(value)"
						}
					}
				}
			}
		}
	}
	...
}

#Configs: [id=string]: {
	{
		file: string | *"./\(id)"
		contents?: string
	} | {
		external: true
		name?: string
	}
}

#Secrets: [id=string]: {
	{
		file: string | *"/var/secrets\(id)"
		contents?: dagger.#Secret
	} | {
		external: true
		name?: string
	}
}

#App: {
	project: string
	services?: [string]: #Service & {
		"project": project
	}
	C=configs?: #Configs
	S=secrets?: #Secrets
	V=volumes?: _
	N=networks?: _
	output: spec.#Compose & {
		if services != _|_ {
			"services": {
				for name, service in services {
					"\(name)": {
						for field, value in service {
							if !list.Contains(["project", "networks", "configs", "secrets", "volumes", "traefik"], field) {
								"\(field)": value
							}
							if field == "networks" {
								for network, config in service.networks {
									if config != null {
										networks: "\(network)": config
									}
								}
							}
							if field == "volumes" {
								volumes: [
									for k, v in service.volumes {
										"\(k):\(v)",
									}
								]
							}
							if field == "configs" || field == "secrets" {
								"\(field)": [ for x in value { x } ]
							}
						}
					}
				}
			}
			for name, service in services {
				if service.networks != _|_ {
					for network, config in service.networks {
						if network != "default" && config != null {
							networks: "\(network)": {
								external: true
								name: string | *"\(network)_default"
							}
						}
					}
				}
			}
		}
		if C != _|_ {
			for key, config in C {
				configs: "\(key)": {
					for field, value in config {
						if field != "contents" {
							"\(field)": value
						}
					}
				}
			}
		}
		if S != _|_ {
			for key, config in S {
				secrets: "\(key)": {
					for field, value in config {
						if field != "contents" {
							"\(field)": value
						}
					}
				}
			}
		}
		if V != _|_ {
			volumes: V
		}
		if N != _|_ {
			networks: N
		}
	}
	export: lib.#SaveFiles & {
		input: dagger.#Scratch
		files: {
			"compose.yaml": contents: yaml.Marshal(output)
			if C != _|_ {
				for config in C {
					if config.contents != _|_ {
						let key = path.Clean(config.file)
						"\(key)": contents: config.contents
					}
				}
			}
		}
	}
	mounts: {
		configs: {
			dest: "/var/configs"
			contents: export.output
		}
		if S != _|_ {
			for sid, secret in S {
				if secret.contents != _|_ {
					"\(sid)": {
						dest: secret.file
						contents: secret.contents
					}
				}
			}
		}
	}
	...
}
