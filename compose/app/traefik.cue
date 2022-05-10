package app

import (
    "encoding/yaml"
)

Traefik: {
    let base_conf_dir = "/etc/traefik"

    P=ports: {
        http: null | int | *80
        https: null | int | *443
    }

    D=dashboard?: {
        domain: string
        users: [...string]
    }

    H=host?: {
        ip: string
        port: string | *"8080"
    }

    email: string

    params: {
        providers: {
            docker: {
                network: string | *"ingress_default"
                exposedByDefault: false
            }
            file: {
                directory: "\(base_conf_dir)/conf.d"
                watch: true
            }
        }
    }

    if P.http != null {
        params: entrypoints: web: {
            address: ":\(P.http)"
            // FIXME: turn on when all sites are using https
            // http: redirections: entryPoint: to: "websecure"
        }
    }
    if P.https != null {
        params: {
            entrypoints: websecure: {
                address: ":\(P.https)"
                http: {
                    middlewares: "secure-headers@file"
                    tls: {
                        // options: "modern@file"
                        certresolver: "le"
                    }
                }
            }
            certificatesResolvers: le: acme: {
                tlschallenge: true
                "email": email
                storage: "\(base_conf_dir)/acme/acme.json"
                caServer: string | *"https://acme-v02.api.letsencrypt.org/directory"
            }
        }
        confs: secure: {
            tls: options: default: {
                sniStrict: true
                minVersion: "VersionTLS12"
                cipherSuites: [
                    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
                    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
                    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
                    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
                    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
                ]
            }
            http: {
                middlewares: {
                    "secure-redirect": redirectScheme: {
                        scheme: "https"
                        permanent: true
                    }
                    "secure-redirect-temporary": redirectScheme: {
                        scheme: "https"
                        permanent: false
                    }
                    "secure-headers": headers: {
                        stsSeconds: "31536000"
                        stsIncludeSubdomains: true
                        stsPreload: true
                        forceSTSHeader: true
                        referrerPolicy: "same-origin"
                    }
                }
            }
        }
        if P.http != null {
            confs: secure: http: {
                services: noop: loadBalancer: servers: [
                    // just because we need a service even for redirects
                    "http://127.0.0.1",
                ]
                routers: "http-redirect": {
                    rule: "HostRegexp(`{host:.+}`)"
                    priority: 1
                    service: "noop"
                    entrypoints: ["web"]
                    middlewares: ["secure-redirect@file"]
                }
            }
        }
    }
    confs: [string]: {...}
    if D != _|_ {
        params: api: {}
        services: proxy: traefik: router: {
            rule: "Host(`\(dashboard.domain)`)"
            service: "api@internal"
        }
        if len(D.users) > 0 {
            confs: dashboard: {
                http: middlewares: "dashboard-auth": basicAuth: {
                    users: D.users
                }
            }
            services: proxy: traefik: middlewares: "dashboard-auth": _
        }
    }
    if H != _|_ {
        services: proxy: extra_hosts: [
            "host.docker.internal:\(H.ip)"
        ]
        confs: host: http: services: "host-svc": loadBalancer: servers: [
            { url: "http://host.docker.internal:\(H.port)" },
        ]
    }
    services: proxy: {
        image: string | *"traefik:v2.6.1"
        ports: [
            if P.http != null {
                "\(P.http):\(P.http)"
            },
            if P.https != null {
                "\(P.https):\(P.https)"
            },
        ]
        volumes: {
            acme: "\(base_conf_dir)/acme"
            "./traefik.yaml": "\(base_conf_dir)/traefik.yaml:ro"
            "./conf.d": "\(params.providers.file.directory):ro"
            "/var/run/docker.sock": _
        }
    }
    volumes: acme: _
    export: {
        files: {
            "traefik.yaml": contents: yaml.Marshal(params)
            for name, conf in confs {
                "conf.d/\(name).yaml": contents: yaml.Marshal(conf)
            }
        }
    }
}
