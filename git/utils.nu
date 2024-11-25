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
    let d = _git_log --verbose -n 9
    mut r = {}
    for i in $d {
        if ($i.file > 0) {
            $r = $i
            break
        }
    }
    $r | rename hash message
}

export def git-cdup [] {
    let r = git rev-parse --show-cdup | complete
    if $r.exit_code == 0 {
        $r.stdout | str trim
    }
}

export def git-repo-path [] {
    let c = git-cdup
    if ($c | describe) == nothing { return }
    [$env.PWD (git-cdup)] | path join | path expand
}

export def git-sync [
    src dest
    --no-file
    --push
    --init: string
    --post-sync: closure
    --init-post-sync: closure
    --trans-name: closure
] {
    let src = $src | path expand
    cd $src
    let l = git-last-commit
    let msg = if ($trans_name | is-empty) { $l.message } else { do $trans_name $l.message }
    let dest = $dest | path expand
    if not ($dest | path exists) { mkdir $dest }
    cd $dest
    if not $no_file {
        rsync -a --delete --exclude='.git' $'($src)/' $dest
        if ($post_sync | is-not-empty) and (git-is-repo) {
            do $post_sync $src $dest $l
        }
        if ($init_post_sync | is-not-empty) {
            do $init_post_sync $src $dest $l
        }
    }
    if ($init | is-not-empty) and not (git-is-repo) {
        git init .
        git remote add origin $init
        git add .
        git commit -m $msg
        if $push {
            git push --set-upstream origin main
        }
    }
    if (git-changes | is-not-empty) {
        git add .
        git commit -m $msg
        if $push {
            git push
        }
    }
}
