# ADDED JBY
#
# INSTALL: add to end of .bashrc
#
# if [ -f ~/.jby_bashrc.sh ]; then . ~/.jby_bashrc.sh; fi
#

#------------------------------------------------------------
# PATH modifications (must come first)
#------------------------------------------------------------
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# add cargo binaries to PATH if not already present
case ":${PATH}:" in
*:"$HOME/.cargo/bin":*) ;;
*)
  export PATH="$HOME/.cargo/bin:$PATH"
  ;;
esac

#------------------------------------------------------------
# Environment variables
#------------------------------------------------------------
export loc_linux_kernel_generic=/usr/src/linux-headers-$(uname -r)
export loc_linux_kernel=/usr/src/linux-headers-$(basename $(uname -r) -generic)

# DPDK
export DPDK_VER=dpdk-stable
export RTE_SDK=$HOME/tools/${DPDK_VER}
case "$(uname -m)" in
  x86_64)  export RTE_TARGET=x86_64-native-linux-gcc ;;
  aarch64) export RTE_TARGET=arm64-native-linux-gcc ;;
  *)       export RTE_TARGET=native-linux-gcc ;;
esac
export PKG_CONFIG_PATH=~/tools/${DPDK_VER}/build/meson-private:$PKG_CONFIG_PATH

#------------------------------------------------------------
# Aliases
#------------------------------------------------------------
alias ls='ls -x --color=auto --group-directories-first'
alias la='ls -Ax --color=auto --group-directories-first'
alias ll='ls -l --color=auto --group-directories-first'
alias lll='ls -lA --color=auto --group-directories-first'
alias rsyncp='rsync -avzh --info=progress2 --info=name0 --stats'
alias tmux='tmux -2'

# DPDK aliases
alias dpstat='~/tools/${DPDK_VER}/usertools/dpdk-devbind.py --status'
alias dpbind='/usr/bin/sudo -E ~/tools/${DPDK_VER}/usertools/dpdk-devbind.py --force --bind=igb_uio'
alias dpunbind='/usr/bin/sudo -E ~/tools/${DPDK_VER}/usertools/dpdk-devbind.py -u'

#------------------------------------------------------------
# Shell features (history, prompt)
#------------------------------------------------------------
PS1='\n\[\e[01;36m\]\u \[\e[0m\]on \[\e[01;33m\]\h \[\e[0m\]in \[\e[01;34m\]\w\[\e[0m\]\n$ '
export HISTSIZE=2000
export HISTFILESIZE=2000
export HISTIGNORE="&:[ ]*:exit:ls:la:ll:lll:history:env sh /tmp/Microsoft-MIEngine-Cmd*"
# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
# Turn off history substitution "!" in bash commands.
set +H

#------------------------------------------------------------
# SSH agent (ensures agent runs for git access with key files)
#------------------------------------------------------------
if [[ $- == *i* ]]; then
  SSH_ENV="$HOME/.ssh/environment"

  start_agent() {
    echo "Initialising new SSH agent..."
    mkdir -p "$HOME/.ssh"
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"${SSH_ENV}"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" >/dev/null
    # Only add keys if they exist
    find "$HOME/.ssh" -maxdepth 1 -name 'id_*' ! -name '*.pub' -type f 2>/dev/null | head -1 | grep -q . && /usr/bin/ssh-add
  }

  if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" >/dev/null
    # Check if agent is actually running using kill -0
    if ! kill -0 "${SSH_AGENT_PID}" 2>/dev/null; then
      start_agent
    fi
  else
    start_agent
  fi
fi

#------------------------------------------------------------
# Starship prompt (overrides PS1, requires PATH to be set)
#------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init bash)"

#------------------------------------------------------------
# Tmux session detection (last, may launch new shell)
#------------------------------------------------------------
if command -v tmux &>/dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  if [ "$TERM_PROGRAM" == "vscode" ]; then
    echo "vscode detected. running standard shell."
  else
    # ansible logs in as a 'dumb' terminal. Let's not add tmux on top of it.
    if [ "$TERM" != "dumb" ]; then
      echo "tmux sessions:"
      tmux ls
    fi
  fi
fi
