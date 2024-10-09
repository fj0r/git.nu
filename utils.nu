export def git-init [remote] {
    git init --initial-branch main
    git add .
    git commit -m 'init'
    git remote add origin $remote
}

export def git-is-repo [] {
    (git rev-parse --is-inside-work-tree | complete).exit_code == 0
}

export def git-changes [] {
    do -i { git --no-optional-locks status --porcelain=1 | lines }
}

export def git-last-commit [] {
    let d = git log --reverse -n 1 --pretty=%h»¦«%s | split row '»¦«'
    {
        hash: $d.0
        message: $d.1
    }
}

export def git-cdup [] {
    let r = git rev-parse --show-cdup | complete
    if $r.exit_code == 0 {
        $r.stdout | str trim
    }
}
