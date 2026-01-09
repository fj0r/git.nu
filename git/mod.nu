export use stat.nu *
export use utils.nu *
export use core.nu *
export use histogram.nu *
export use git-flow.nu *

export-env {
    $env.GIT_COMMIT_TYPE = {
        feat: 'feat: {}'
        fix: 'fix: {}'
        docs: 'docs: {}'
        style: 'style: {}'
        refactor: 'refactor: {}'
        perf: 'perf: {}'
        test: 'test: {}'
        chore: 'chore: {}'
    }
    export use git-flow.nu
}

