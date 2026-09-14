
    LAST_GENERATION_NUMBER=$(nixos-rebuild list-generations | head -n2 | tail -n1 | cut -d ' ' -f1)

    echo "${LAST_GENERATION_NUMBER}"
