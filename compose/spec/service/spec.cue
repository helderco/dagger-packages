package service

#Service: {
    image: string
    restart: #Restart
    init?: bool
    command?: [...string] | string
    user?: string
    container_name?: string
    depends_on?: [...string]
    networks?: [string]: #Network
    ports?: [...string]
    extra_hosts?: [...string]
    healthcheck?: #Healthcheck
    configs?: [...#Config]
    secrets?: [...#Secret]
    volumes?: [...string]
    working_dir?: string
    environment?: _#Map
    labels?: _#Map
    deploy?: #Deploy
}

#Restart: "no" | *"always" | "on-failure" | "unless-stopped"

#Network: {
    aliases?: [...string]
}

#Config: string | {
    source: string
    target?: string
    uid?: string
    gid?: string
    mode?: int
}

#Secret: #Config

#Healthcheck: {
    disable?: bool
    test?: string | [...string]
    interval?: #Duration
    timeout?: #Duration
    retries?: int
    start_period?: #Duration
}

_#Map: [string]: string | bool | int

#Deploy: {
    labels?: [string]: string
    mode?: "global" | "replicated"
    constraints?: [string]: string
    preferences?: [string]: string
    replicas?: int
    resources?: ["limits" | "reservations"]: {
        cpus?: string
        memory?: #Byte
        pids?: int
    }
    restart_policy?: {
        condition?: "none" | "on-failure" | "any"
        delay?: #Duration
        max_attempts?: int
        window?: #Duration
    }
}

// FIXME: duration (https://github.com/compose-spec/compose-spec/blob/master/spec.md#specifying-durations)
#Duration: string

// FIXME: byte value (https://github.com/compose-spec/compose-spec/blob/master/spec.md#specifying-byte-values)
#Byte: string
