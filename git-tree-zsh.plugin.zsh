#!/bin/zsh
fpath+="${0:h}/completions"

gt_help() {
    echo "fzf powered git worktree helper
usage: git-tree (switch | -s | -S)              Switches directory
   or: git-tree list (-l | -L)                  List git worktrees and print path of selected
   or: git-tree add (-a | -A) (--skip)          Creates a new git worktree from an existing remote branch
   or: git-tree remove (-d | -D)                Removes a git worktree
   or: git-tree new (-n | -N) <branch> (--skip) Creates a new git worktree with a new local branch
   or: git-tree clean (-c | -C)                 Clean all worktrees which do not have a corresponding remote branch and prune worktrees


If you add a hook.sh file to your git worktree root this file will be executed whenever a new
git worktree is created by git-tree add or git-tree new. You can skip executing the script by adding the --skip option to your command. 
"
}

gt_is_subdir() {
    local child="$2"
    local parent="$1"
    if [[ "${child##${parent}}" != "$child" ]]; then
        return 0
    else
        return 1
    fi
}

git-tree() {
    if ! which fzf-tmux >/dev/null; then
        echo "Error: fzf is not installed, run 'brew install fzf' to install."
        echo "See https://github.com/junegunn/fzf\n"
        gt_help
        return 1
    elif [ -z "$1" ] || [ "$1" = "switch" ] || [ "$1" = "-s" ] || [ "$1" = "-S" ]; then
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
    elif [ "$1" = "add" ] || [ "$1" = "-a" ] || [ "$1" = "-A" ]; then
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
        if [[ -f "$root/hook.sh" && ! -z  "$branch" && "$2" != "--skip" ]]; then
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
            git push --set-upstream origin $2
            if [[ -f "$root/hook.sh" && "$3" != "--skip" ]]; then
                bash "$root/hook.sh" "$newPath"
            fi
        else
            gt_help
        fi
    elif [ "$1" = "remove" ] || [ "$1" = "-d" ] || [ "$1" = "-D" ]; then
        local root worktrees branches selection currentdir worktreepath
        currentdir=$(pwd) &&
        root=$(git worktree list | head -1 | awk '{print $1}') &&
        worktrees=$(basename $(git worktree list | head -1 | awk '{print $1}'))-worktrees &&
        branches=$(git worktree list) &&
        selection=$(echo "$branches" |rev|awk '{print $1}'|cut -b 2-|rev|cut -b 2- | fzf-tmux -p 80% --no-sort --ansi -0 --height=50% --preview-window 70% --preview 'if output=$(git log origin/{} --color --graph --oneline &>/dev/null); then git fetch &>/dev/null && git log origin/{} --color --graph --oneline; else echo "No log"; fi' +m) &&
        worktreepath=$(echo "$root/../$worktrees/$selection")

        if [[ ! -z "$selection" ]]; then
            if gt_is_subdir $(realpath $worktreepath) "$currentdir"; then 
                cd $root
            fi
            git worktree remove $(echo "$selection" | head -1 | awk '{print $1}') --force;
        fi
    elif [ "$1" = "clean" ] || [ "$1" = "-c" ] || [ "$1" = "-C" ]; then
        DRYRUN=0
        if [[ "$2" = "--dry-run" ]]; then
            DRYRUN=1
        fi

        WORKTREES_TO_REMOVE=()
        lines=$(git worktree list |rev|awk '{print $1}'|cut -b 2-|rev|cut -b 2-)
        declare -a worktrees
        while read -r line
        do
            worktrees+=("$line")            
        done <<< "$lines"
        for worktree in $worktrees; do
          git ls-remote --heads origin $worktree | grep $worktree >/dev/null
          if [[ "$?" == "1" && $worktree != "bare" ]]; then
            WORKTREES_TO_REMOVE+=($worktree)
          fi
        done

        if [[ ! -z $WORKTREES_TO_REMOVE ]]; then
          echo "Found ${#WORKTREES_TO_REMOVE[@]} worktree(s) without remote branch"
          if [ $DRYRUN = 0 ]; then
            for branch in "${WORKTREES_TO_REMOVE[@]}"
            do
              read "CONT?Do you want to remove the worktree: $branch? [y/n] "
              if [ "$CONT" = "y" ] || [ -z $CONT ]; then
                git worktree remove "$branch" --force;
              else
                echo "No action taken";
                continue
              fi
            done
          else
            echo "Would delete the following worktrees:"
            for branch in "${WORKTREES_TO_REMOVE[@]}"
            do
              echo $branch
            done
          fi
        else
          echo "No worktrees found without remote."
        fi
    else
        gt_help
    fi
}

alias gt="git-tree"
