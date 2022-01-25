#!/bin/zsh
fpath+="${0:h}/completions"

gt_help() {
    echo "fzf powered git worktree helper
usage: git-tree (switch)               Switches directory
   or: git-tree list (-l | -L)         List git worktrees and print path of selected
   or: git-tree add (-c | -C)          Creates a new git worktree from an existing remote branch
   or: git-tree remove (-d | -D)       Removes a git worktree
   or: git-tree new (-n | -N)          Creates a new git worktree with a new local branch

If you add a hook.sh file to your git worktree root this file will be executed whenever a new
git worktree is created by git-tree add or git-tree new. 
"
}

git-tree() {
    if ! which fzf-tmux >/dev/null; then
        echo "Error: fzf is not installed, run 'brew install fzf' to install."
        echo "See https://github.com/junegunn/fzf\n"
        gt_help
        return 1
    elif [ -z "$1" ] || [ "$1" = "switch" ] || [ "$1" = "-s" ]; then
        local root worktrees branches selection worktreepath
        root=$(git worktree list | head -1 | awk '{print $1}') &&
        worktrees=$(basename $(git worktree list | head -1 | awk '{print $1}'))-worktrees &&
        branches=$(git worktree list) &&
        selection=$(echo "$branches" |rev|awk '{print $1}'|cut -b 2-|rev|cut -b 2- | fzf-tmux -p 80% --no-sort --ansi -0 --height=50% --preview-window 70% --preview 'if output=$(git log origin/{} --color --graph --oneline &>/dev/null); then git fetch &>/dev/null && git log origin/{} --color --graph --oneline; else echo "No log"; fi' +m) &&
        worktreepath=$(echo "$root/../$worktrees/$selection") &&
        cd $(echo "$worktreepath");
    elif [ "$1" = "list" ] || [ "$1" = "-l" ] || [ "$1" = "-L" ]; then
        local root worktrees branches selection
        root=$(git worktree list | head -1 | awk '{print $1}') &&
        worktrees=$(basename $(git worktree list | head -1 | awk '{print $1}'))-worktrees &&
        branches=$(git worktree list) &&
        selection=$(echo "$branches" |rev|awk '{print $1}'|cut -b 2-|rev|cut -b 2- | fzf-tmux -p 80% --no-sort --ansi -0 --height=50% --preview-window 70% --preview 'if output=$(git log origin/{} --color --graph --oneline &>/dev/null); then git fetch &>/dev/null && git log origin/{} --color --graph --oneline; else echo "No log"; fi' +m) &&
        echo "$selection" | head -1 | awk '{print $1}';
    elif [ "$1" = "add" ] || [ "$1" = "-c" ] || [ "$1" = "-C" ]; then
        local root worktrees remote allbranches branches branch newPath
        root=$(git worktree list | head -1 | awk '{print $1}') &&
        worktrees=$(basename $(git worktree list | head -1 | awk '{print $1}'))-worktrees &&
        remote=$(git remote show) &&
        allbranches=$(git branch -la --sort=-committerdate --format="%(refname:short)") &&
        branches=$(echo "$allbranches" | sed "s/$remote\///g" | awk '! seen[$0]++') &&
        branch=$(echo "$branches" | fzf-tmux -p 80% --no-sort --ansi -0 --height=50% --preview-window 70% --preview 'if output=$(git log origin/{} --color --graph --oneline &>/dev/null); then git fetch &>/dev/null && git log origin/{} --color --graph --oneline; else echo "No log"; fi' +m) &&
        newPath=$(echo "$root/../$worktrees/$branch") &&
        git worktree add $newPath $branch &&
        cd $newPath
        if [[ -f "$root/hook.sh" && ! -z  "$branch" ]]; then
            bash "$root/hook.sh" "$newPath"
        fi
    elif [ "$1" = "new" ] || [ "$1" = "-n" ] || [ "$1" = "-N" ]; then
        local root worktrees newPath
        root=$(git worktree list | head -1 | awk '{print $1}') &&
        worktrees=$(basename $(git worktree list | head -1 | awk '{print $1}'))-worktrees 
        if [[ ! -z "$2" ]]; then
            newPath=$(echo "$root/../$worktrees/$2")
            git worktree add -b $2 $newPath
            cd $newPath
            if [[ -f "$root/hook.sh" ]]; then
                bash "$root/hook.sh" "$newPath"
            fi
        else
            gt_help
        fi
    elif [ "$1" = "remove" ] || [ "$1" = "-d" ] || [ "$1" = "-D" ]; then
        local root worktrees branches selection
        root=$(git worktree list | head -1 | awk '{print $1}') &&
        worktrees=$(basename $(git worktree list | head -1 | awk '{print $1}'))-worktrees &&
        branches=$(git worktree list) &&
        selection=$(echo "$branches" |rev|awk '{print $1}'|cut -b 2-|rev|cut -b 2- | fzf-tmux -p 80% --no-sort --ansi -0 --height=50% --preview-window 70% --preview 'if output=$(git log origin/{} --color --graph --oneline &>/dev/null); then git fetch &>/dev/null && git log origin/{} --color --graph --oneline; else echo "No log"; fi' +m) &&
        git worktree remove $(echo "$selection" | head -1 | awk '{print $1}') --force;
    else
        gt_help
    fi
}

alias gt="git-tree"
