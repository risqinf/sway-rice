if status is-interactive
    function clear
        command clear
        printf '\e[3J'
    end

    clear
    fastfetch
end

# Pastikan TERM selalu xterm-256color agar kompatibel saat SSH ke server yang
# tidak punya terminfo kitty (xterm-kitty). kitty sudah set ini via kitty.conf,
# tapi baris ini mengamankan sesi SSH/tmux yang mewarisi TERM salah.
if test "$TERM" = "xterm-kitty"
    set -gx TERM xterm-256color
end
