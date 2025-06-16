[core]
    editor = vim
    autocrlf = false
    #pager = delta --theme="DarkNeon" --file-style=box
[diff]
    wsErrorHighlight = all        
[alias]
    tree = log --all --graph
    unstage = reset HEAD --
    discard = checkout
    ll = log --pretty=format:'%Cred%h%Creset %Cgreen(%cr)%Creset%C(yellow)%d%Creset %s %C(bold blue)<%an>%Creset' --abbrev-commit
    llg = log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all
    llga = log --graph --decorate --oneline
    llgt = log --graph --decorate --oneline --simplify-by-decoration
    difm = diff --diff-filter=M
    difms = diff --diff-filter=M --staged
[color]
    ui = true
[color "diff-highlight"]
    oldNormal = red bold
    oldHighlight = red bold 52
    newNormal = green bold
    newHighlight = green bold 22
[color "diff"]
    meta = yellow
    frag = magenta bold
    commit = yellow bold
    old = red bold
    new = green bold
    whitespace = red reverse
[pull]
    rebase = true
    