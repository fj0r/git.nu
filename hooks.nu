use utils.nu *

export-env {
    $env.GIT_HOOKS = {
        # commit
        pre-commit: {type: commit, default: true}
        pre-merge-commit: {type: commit, default: true}
        prepare-commit-msg: {type: commit}
        commit-msg: {type: commit}
        post-commit: {type: commit, default: true}
        # email
        applypatch-msg: {type: email}
        pre-applypatch: {type: email}
        post-applypatch: {type: email}
        # client
        pre-rebase: {type: client}
        post-rewrite: {type: client}
        post-checkout: {type: client}
        post-merge: {type: client}
        pre-push: {type: client, default: true}
        pre-auto-gc: {type: client}
        push-to-checkout: {type: client}
        reference-transaction: {type: client}
        # server
        pre-receive: {type: server}
        update: {type: server}
        post-update: {type: server}
        post-receive: {type: server}

        fsmonitor-watchman: {type: other}
    }
}

export def git-list-hooks [] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hp = [$c .git hooks] | path join
    ls $hp | get name | path parse
    | filter {|x| ($x.extension | is-empty) and ($x.stem in $env.GIT_HOOKS) }
    | get stem
}

def cmpl-hooks [] {
    $env.GIT_HOOKS | columns
}

def outdent [] {
    let txt = $in | lines | range 1..
    let indent = $txt.0 | parse --regex '^(?P<indent>\s*)' | get indent.0 | str length
    $txt
    | each {|s| $s | str substring $indent.. }
    | str join (char newline)
}

export def git-uninstall-hooks [...hooks:string@git-list-hooks] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hp = [$c .git hooks] | path join
    let hs = if ($hooks | is-empty) { git-list-hooks } else { $hooks }
    for h in $hs {
        rm -f ([$hp $h] | path join)
    }
}

export def git-install-hooks [
    ...hooks:string@cmpl-hooks
    --mod(-m)="__"
    --fun(-f)="git-hooks"
    --direnv
] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hp = [$c .git hooks] | path join
    let rp = [$env.PWD $c] | path join | path expand
    let hs = $env.GIT_HOOKS | transpose k v
    let hs = if ($hooks | is-empty) { $hs | filter {$in.v.default?} } else { $hs | where k in $hooks }
    for h in $hs {
        let p = [$hp $h.k] | path join
        $"
        #!/bin/env nu
        use ../../($mod).nu
        (if $direnv { 'use direnv' })

        export def main [...argv:string] {
            if \(scope commands | where name == '($mod) ($fun)' | is-empty\) {
                print $'\(ansi grey\)The `($fun)` function is undefined.\(ansi reset\)'
            } else {
                let wd = $env.CURRENT_FILE
                | path split
                | split list '.git'
                | range ..<-1
                | flatten
                | path join

                cd $wd

                (if $direnv { 'direnv' })

                let cm = git log --reverse -n 1 --pretty=%h»¦«%s | split row '»¦«'

                ($mod) ($fun) '($h.k)' {
                    workdir: $env.PWD
                    hash: $cm.0
                    message: $cm.1
                    remote: $argv.0?
                    repo: $argv.1?
                }
            }
        }
        "
        | outdent
        | save -f $p
        chmod +x $p
    }
}
