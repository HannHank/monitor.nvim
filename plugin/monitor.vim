" Expose the plugins functions for use as commands in Neovim
command! -nargs=* Monitor lua require('monitor').monitor(<f-args>)
