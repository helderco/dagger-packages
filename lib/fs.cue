package lib

import (
    "list"
    osPath "path"
    "dagger.io/dagger"
    "dagger.io/dagger/core"
)

// We need to make sure that directories exists, when using #WriteFile
#SaveFile: {
    // Input filesystem tree
    I=input: dagger.#FS
    // Path of the file to write
    P=path: string
    // Contents to write
    C=contents: string

    dir: core.#Mkdir & {
        input: I
        path: osPath.Dir(P)
    }

    file: core.#WriteFile & {
        input: dir.output
        path: P
        contents: C
    }

    // Output filesystem tree
    output: file.output
}

// Generate an #FS with multiple files. Use like:
// export: #SaveFiles & {
//     files: {
//         test1: contents: "foobar"
//         test2: contents: "foobaz"
//         "conf.d/sweet": contents: "sweet"
//     }
// }
#SaveFiles: {
    I=input: dagger.#FS
    output: dagger.#FS
    files: [rel=string]: {
        contents: string
        path: "/\(rel)"
    }
    // sort to ensure that dag is stable
    let sorted = list.SortStrings([for p, _ in files { p }])
    _dag: {
        for idx, key in sorted {
            "\(idx)": #SaveFile & files[key]
            if idx == 0 {
                "0": input: I
            }
            if idx > 0 {
                "\(idx)": input: _dag["\(idx-1)"].output
            }
        }
    }
    if len(_dag) > 0 {
        output: _dag["\(len(_dag)-1)"].output
    }
}
