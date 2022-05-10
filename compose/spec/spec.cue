package spec

import (
    "github.com/helderco/dagger-packages/compose/spec/service"
)

// https://github.com/compose-spec/compose-spec/blob/master/spec.md

#Compose: {
    services?: #Services
    networks?: #Networks
    configs?: #Configs
    secrets?: #Secrets
    volumes?: #Volumes
}

#Services: [string]: service.#Service

#Networks: [string]: #Network
#Network: {
    external?: bool
    name?: string
}

#Configs: [string]: #Config
#Config: { file: string } | { external: true, name?: string }

#Secrets: #Configs

#Volumes: [string]: #Volume
#Volume: {
    external?: bool
    name?: string
}
