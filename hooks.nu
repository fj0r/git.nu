use utils.nu *

export-env {
    $env.GIT_HOOKS = {
        # commit
        pre-commit: {type: commit}
        prepare-commit-msg: {type: commit}
        commit-msg: {type: commit}
        post-commit: {type: commit}
        pre-merge-commit: {type: commit}
        # email
        applypatch-msg: {type: email}
        pre-applypatch: {type: email}
        # client
        pre-rebase: {type: client}
        post-rewrite: {type: client}
        post-checkout: {type: client}
        post-merge: {type: client}
        pre-push: {type: client}
        pre-auto-gc: {type: client}
        push-to-checkout: {type: client}
        # server
        pre-receive: {type: server}
        update: {type: server}
        post-update: {type: server}
        post-receive: {type: server}
    }
}

export def git-list-hooks [] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hp = [$c .git hooks] | path join
    ls $hp | get name | path parse | get stem
}

def cmpl-hooks [] {
    $env.GIT_HOOKS | columns
}

export def git-install-hooks [
    ...hooks:string@cmpl-hooks
    --mod(-m)="__"
    --fun(-f)="git-hooks"
] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hp = [$c .git hooks] | path join
    let rp = [$env.PWD $c] | path join | path expand
    let hs = $env.GIT_HOOKS | transpose k v
    let hs = if ($hooks | is-empty) { $hs } else { $hs | where k in $hooks }
    for h in $hs {
        let p = [$hp $h.k] | path join
        [
            "#!/bin/env nu"
           $"use ../../($mod).nu"
            ""
            "export def main [...argv:string] {"
            "    cd ($env.CURRENT_FILE | path split | range 0..<-1 | path join)"
           $"    if \(scope commands | where name == '($mod) ($fun)' | is-empty\) {"
           $"        print $'\(ansi grey\)The `($fun)` function is undefined.\(ansi reset\)'"
            "    } else {"
           $"        ($mod) ($fun) '($h.k)' $argv"
            "    }"
            "}"
        ]
        | str join (char newline)
        | save -f $p
        chmod +x $p
    }
}
