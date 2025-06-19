# ADDED JBY
#
# INSTALL: add to end of .bashrc
#
# if [ -f ~/jby_bashrc.sh ]; then . ~/jby_bashrc.sh; fi
#
PS1='\n\[\e[01;36m\]\u \[\e[0m\]on \[\e[01;33m\]\h \[\e[0m\]in \[\e[01;34m\]\w\[\e[0m\]\n$ '
export HISTSIZE=2000
export HISTFILESIZE=2000
export HISTIGNORE="&:[ ]*:exit:ls:la:ll:lll:history:env sh /tmp/Microsoft-MIEngine-Cmd*"
# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
# Turn off history substitution "!" in bash commands.
set +H

alias ls='ls -x --color=auto --group-directories-first'
alias la='ls -Ax --color=auto --group-directories-first'
alias ll='ls -l --color=auto --group-directories-first'
alias lll='ls -lA --color=auto --group-directories-first'
alias rsyncp='rsync -avzh --info=progress2 --info=name0 --stats'
alias tmux='tmux -2'

export loc_linux_kernel_generic=/usr/src/kernels/$(uname -r)
export loc_linux_kernel=/usr/src/kernels/$(basename $(uname -r) -generic)

#------------------------------------------------------------
# the following makes sure that ssh-agent runs for each shell
# this is necessary for git access with key files.
SSH_ENV="$HOME/.ssh/environment"

function start_agent {
  echo "Initialising new SSH agent..."
  /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"${SSH_ENV}"
  chmod 600 "${SSH_ENV}"
  . "${SSH_ENV}" >/dev/null
  /usr/bin/ssh-add
}

# Source SSH settings, if applicable

if [ -f "${SSH_ENV}" ]; then
  . "${SSH_ENV}" >/dev/null
  #ps ${SSH_AGENT_PID} doesn't work under cywgin
  ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ >/dev/null || {
    start_agent
  }
else
  start_agent
fi

major=$(cat /etc/centos-release 2>/dev/null | tr -dc '0-9.' | cut -d \. -f1)
if [ -f /etc/centos-release ] && [ $major == "7" ]; then
  # ansible logs in as a 'dumb' terminal. Let's not add tmux on top of it.
  if [ "$TERM" != "dumb" ]; then
    source scl_source enable devtoolset-8 llvm-toolset-7.0
  fi
fi

# lauch shell as tmux session
if command -v tmux &>/dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  if [ "$TERM_PROGRAM" == "vscode" ]; then
    echo "vscode dectected. running standard shell."
  else
    # ansible logs in as a 'dumb' terminal. Let's not add tmux on top of it.
    if [ "$TERM" != "dumb" ]; then
      echo "tmux sessions:"
      tmux ls
    fi
  fi
fi

# DPDK STUFF
export DPDK_VER=dpdk-stable
export RTE_SDK=$HOME/tools/${DPDK_VER}
export RTE_TARGET=x86_64-native-linux-gcc
export PKG_CONFIG_PATH=~/tools/${DPDK_VER}/build/meson-private:$PKG_CONFIG_PATH
alias dpstat='~/tools/${DPDK_VER}/usertools/dpdk-devbind.py --status'
alias dpbind='/usr/bin/sudo -E ~/tools/${DPDK_VER}/usertools/dpdk-devbind.py --force --bind=igb_uio'
alias dpunbind='/usr/bin/sudo -E ~/tools/${DPDK_VER}/usertools/dpdk-devbind.py -u'
