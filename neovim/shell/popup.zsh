# Use ordinary shell editing only inside Neovim popup terminals.
[[ ${NVIM_POPUP_TERMINAL:-} == 1 ]] || return 0
bindkey -e
