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

# add bun + its global bins (gbrain, etc.) to PATH if not already present
export BUN_INSTALL="$HOME/.bun"
case ":${PATH}:" in
*:"$BUN_INSTALL/bin":*) ;;
*)
  export PATH="$BUN_INSTALL/bin:$PATH"
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
# gbrain (personal knowledge brain)
#------------------------------------------------------------
# Cap gbrain's postgres.js connection pool (default 10) so interactive gbrain
# commands don't burst the shared Supabase session pooler and trip Supavisor's
# circuit breaker. See gbrain src/core/db.ts:resolvePoolSize(). The MCP server
# and systemd sync timers set this independently (claude.json env + drop-ins).
export GBRAIN_POOL_SIZE=2

# OPENAI_API_KEY for gbrain embeddings (0600 file populated from Azure KV by
# ~/.gbrain/refresh-openai-key.sh). The DB URL is NOT here — it lives in
# ~/.gbrain/config.json, hydrated from KV by ~/.gbrain/refresh-gbrain-db-url.sh.
[ -f ~/.gbrain/openai.env ] && source ~/.gbrain/openai.env

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
# One agent per user, reachable from every shell — and from tmux panes and
# other long-lived processes — via the STABLE path $SSH_AGENT_SOCK_LINK,
# which is re-pointed at the live agent on each login.
#
# Hardening notes (from a real breakage on 2026-09-16):
#  - Liveness is a POSITIVE probe (`ssh-add -l` exit status), not `kill -0
#    $SSH_AGENT_PID` or `ps | grep`. A live PID does not prove the socket is
#    reachable, which is exactly how this failed: the recorded socket lived
#    under a /tmp dir that had since been reaped, so every shell exported an
#    SSH_AUTH_SOCK that produced "Error connecting to agent".
#  - $SSH_ENV is validated before being sourced. It is machine-written state;
#    if it is ever clobbered with prose, sourcing it executes that prose
#    (this is where "Initialising: command not found" at login came from).
#  - $SSH_ENV is written atomically (temp + mv). A plain `>` truncates in
#    place, so a concurrent login can source a half-written file.
if [[ $- == *i* ]]; then
  SSH_ENV="$HOME/.ssh/environment"
  SSH_AGENT_SOCK_LINK="$HOME/.ssh/agent.sock"

  # Positive liveness probe for the socket named by $1. `ssh-add -l` exits 0
  # with keys loaded, 1 for a running-but-empty agent, 2 when it cannot connect.
  _ssh_agent_alive() {
    [ -n "${1:-}" ] || return 1
    (
      SSH_AUTH_SOCK="$1"
      export SSH_AUTH_SOCK
      ssh-add -l >/dev/null 2>&1
      [ $? -ne 2 ]
    )
  }

  # Only ever source lines this bootstrap itself writes.
  _ssh_env_is_sane() {
    [ -s "${SSH_ENV}" ] || return 1
    ! grep -qvE '^(#|SSH_AUTH_SOCK=|SSH_AGENT_PID=|$)' "${SSH_ENV}"
  }

  # Re-point the stable path at the agent we actually ended up with.
  _ssh_agent_link_refresh() {
    [ -S "${SSH_AUTH_SOCK:-}" ] || return 1
    # Never make the link point at itself.
    case "${SSH_AUTH_SOCK}" in "${SSH_AGENT_SOCK_LINK}") return 0 ;; esac
    ln -sfn "${SSH_AUTH_SOCK}" "${SSH_AGENT_SOCK_LINK}"
  }

  start_agent() {
    echo "Initialising new SSH agent..."
    mkdir -p "$HOME/.ssh"
    local tmp
    tmp="$(mktemp "${SSH_ENV}.XXXXXX")" || return 1
    if /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"${tmp}"; then
      chmod 600 "${tmp}"
      mv -f "${tmp}" "${SSH_ENV}"
    else
      echo "ssh-agent failed to start" >&2
      rm -f "${tmp}"
      return 1
    fi
    . "${SSH_ENV}" >/dev/null
    _ssh_agent_link_refresh
    # Only add keys if they exist, and only on a real terminal — a
    # passphrase-protected key would otherwise block an ansible/cron login.
    if [ -t 0 ] && [ "$TERM" != "dumb" ]; then
      find "$HOME/.ssh" -maxdepth 1 -name 'id_*' ! -name '*.pub' -type f 2>/dev/null | head -1 | grep -q . && /usr/bin/ssh-add
    fi
  }

  # Prefer an agent already reachable via the stable link (it survives across
  # shells); else adopt the one recorded in $SSH_ENV; else start a new one.
  if _ssh_agent_alive "${SSH_AGENT_SOCK_LINK}"; then
    export SSH_AUTH_SOCK="${SSH_AGENT_SOCK_LINK}"
  elif _ssh_env_is_sane && . "${SSH_ENV}" >/dev/null 2>&1 && _ssh_agent_alive "${SSH_AUTH_SOCK:-}"; then
    _ssh_agent_link_refresh && export SSH_AUTH_SOCK="${SSH_AGENT_SOCK_LINK}"
  else
    start_agent && export SSH_AUTH_SOCK="${SSH_AGENT_SOCK_LINK}"
  fi
fi

#------------------------------------------------------------
# Starship prompt (overrides PS1, requires PATH to be set)
#------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init bash)"

#------------------------------------------------------------
# Machine-local overrides
#------------------------------------------------------------
# Put anything host-specific here — API-key sourcing, per-box paths, editor
# choice — NOT at the end of ~/.bashrc. This file is unmanaged and survives
# reinstall, and it is sourced after everything above, so it can deliberately
# override what this file sets.
#
# Appending to ~/.bashrc instead is how the ssh-agent broke on 2026-09-16: a
# hand-added `export SSH_AUTH_SOCK=~/.ssh/agent.sock` ran *after* .bashrc
# sourced this file, silently replacing the agent socket this file had just
# set up — with a symlink that no longer resolved.
[ -f "$HOME/.jby_bashrc.local.sh" ] && . "$HOME/.jby_bashrc.local.sh"

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
