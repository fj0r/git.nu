use utils.nu *

export-env {
    $env.GIT_HOOKS = [
        applypatch-msg
        commit-msg
        fsmonitor-watchman
        post-update
        pre-applypatch
        pre-commit
        pre-merge-commit
        pre-push
        pre-rebase
        pre-receive
        prepare-commit-msg
        push-to-checkout
        update
    ]
}

export def git-list-hooks [] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hs = [$c .git hooks] | path join
    ls $hs | get name | path parse | get stem
}

export def git-install-hooks [] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    let hs = [$c .git hooks] | path join
    for h in $env.GIT_HOOKS {
        [
            "#!/bin/env nu"
            ""
            $"git-hooks ($h)"
        ]
        | str join (char newline)
        | save -f ([$hs $h])
    }
}
