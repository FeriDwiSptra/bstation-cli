#!/usr/bin/env bash

bstation() {
    if [[ -z "$1" ]]; then
        echo "Usage:"
        echo "  bstation \"judul anime\""
        echo "  bstation \"judul anime\" <episode>"
        return 1
    fi

    local keyword="$1"
    local direct_ep="$2"

    # --------------------------------------------------
    # Search anime
    # --------------------------------------------------

    local encoded_keyword
    encoded_keyword=$(jq -rn --arg q "$keyword" '$q | @uri')

    local search_url="https://api.bilibili.tv/intl/gateway/web/v2/search_v2/anime?keyword=${encoded_keyword}&pn=1&ps=20&sort=0&duration_type=0&s_locale=id_ID&platform=web"

    local search_file
    search_file=$(mktemp)

    echo "Mencari anime: '$keyword'..."

    curl -sS \
        -A "Mozilla/5.0" \
        "$search_url" \
        -o "$search_file"

    # Pastikan response adalah JSON valid
    if ! jq empty "$search_file" 2>/dev/null; then
        echo "Gagal membaca response API Bstation."
        rm -f "$search_file"
        return 1
    fi

    # Cek API error
    if [[ "$(jq -r '.code // -1' "$search_file")" != "0" ]]; then
        echo "API Bstation mengembalikan error:"
        jq -r '.message // "Unknown error"' "$search_file"
        rm -f "$search_file"
        return 1
    fi

    # --------------------------------------------------
    # Ambil hasil pencarian
    # --------------------------------------------------

    local -a anime_titles
    local -a anime_season_ids

    mapfile -t anime_titles < <(
        jq -r '
            .data.items[]?
            | select(
                (.title? // "" | tostring | length) > 0
                and
                (.season_id? // "" | tostring | length) > 0
            )
            | .title
        ' "$search_file"
    )

    mapfile -t anime_season_ids < <(
        jq -r '
            .data.items[]?
            | select(
                (.title? // "" | tostring | length) > 0
                and
                (.season_id? // "" | tostring | length) > 0
            )
            | .season_id
        ' "$search_file"
    )

    rm -f "$search_file"

    # Tidak ada hasil
    if (( ${#anime_titles[@]} == 0 )); then
        echo
        echo "Anime tidak ditemukan."
        return 1
    fi

    local anime_count=${#anime_titles[@]}
    local i

    echo
    echo "=== Hasil Pencarian ==="
    echo

    for ((i = 0; i < anime_count; i++)); do
        printf "[%d] %s\n" \
            "$((i + 1))" \
            "${anime_titles[$i]}"
    done

    echo
    printf "Pilih anime [1-%d] (q untuk keluar): " "$anime_count"
    read -r choice

    [[ "$choice" == "q" ]] && return 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       (( choice < 1 || choice > anime_count )); then
        echo "Pilihan tidak valid."
        return 1
    fi

    local selected_index=$((choice - 1))

    local selected_anime="${anime_titles[$selected_index]}"
    local selected_season_id="${anime_season_ids[$selected_index]}"

    echo
    echo "Anime: $selected_anime"
    echo "Mengambil daftar episode..."

    # --------------------------------------------------
    # Get episodes
    # --------------------------------------------------

    local episodes_url="https://api.bilibili.tv/intl/gateway/web/v2/ogv/play/episodes?season_id=${selected_season_id}&platform=web&s_locale=id_ID&m_locale=id_ID"

    local episodes_file
    episodes_file=$(mktemp)

    curl -sS \
        -A "Mozilla/5.0" \
        "$episodes_url" \
        -o "$episodes_file"

    if ! jq empty "$episodes_file" 2>/dev/null; then
        echo "Gagal membaca daftar episode."
        rm -f "$episodes_file"
        return 1
    fi

    if [[ "$(jq -r '.code // -1' "$episodes_file")" != "0" ]]; then
        echo "API Bstation mengembalikan error:"
        jq -r '.message // "Unknown error"' "$episodes_file"
        rm -f "$episodes_file"
        return 1
    fi

    # --------------------------------------------------
    # Direct episode mode
    #
    # Example:
    # bstation "one piece" 500
    # --------------------------------------------------

    if [[ -n "$direct_ep" ]]; then

        if ! [[ "$direct_ep" =~ ^[0-9]+$ ]]; then
            echo "Nomor episode harus berupa angka."
            rm -f "$episodes_file"
            return 1
        fi

        local target_ep="E${direct_ep}"
        local direct_result

        direct_result=$(jq -r --arg ep "$target_ep" '
    [
        .data.sections[] as $section |
        $section.episodes[] |
        select(.short_title_display == $ep) |
        {
            section: $section.title,
            episode_id: .episode_id,
            title: .title_display,
            limit_text: .limit_text
        }
    ]
    | if length == 0 then
        empty
      elif length == 1 then
        .[0]
      else
        (
            map(select(.section | test("retake"; "i") | not))
            | if length > 0 then .[0] else .[0] end
        )
      end
    | [
        .episode_id,
        .title,
        (.limit_text // "")
    ]
    | @tsv
' "$episodes_file")

        if [[ -z "$direct_result" ]]; then
            echo "Episode E${direct_ep} tidak ditemukan."
            rm -f "$episodes_file"
            return 1
        fi

        local selected_ep_id
        local selected_ep_title
        local selected_limit

        IFS=$'\t' read -r \
            selected_ep_id \
            selected_ep_title \
            selected_limit <<< "$direct_result"

        rm -f "$episodes_file"

        if [[ "$selected_limit" == "Premium" ]]; then
    echo "Memutar: $selected_ep_title [PREMIUM]"
    echo
    echo "If video has a [Premium] label, it cannot be played unless your Bstation account has a Premium subscription."
else
    echo "Memutar: $selected_ep_title"
fi

echo

mpv \
    --ytdl-raw-options="cookies-from-browser=firefox" \
    --slang=id \
    "https://www.bilibili.tv/id/play/${selected_season_id}/${selected_ep_id}"

return $?
    fi

    # --------------------------------------------------
    # Get sections
    # --------------------------------------------------

    local -a section_titles
    local -a section_ranges

    mapfile -t section_titles < <(
        jq -r '
            .data.sections[]?
            | .title // "Episodes"
        ' "$episodes_file"
    )

    mapfile -t section_ranges < <(
        jq -r '
            .data.sections[]?
            |
            if .ep_list_title then
                .ep_list_title
            elif (.episodes | length) > 0 then
                "\(.episodes[0].short_title_display // "?")-\(.episodes[-1].short_title_display // "?")"
            else
                "?"
            end
        ' "$episodes_file"
    )

    local section_count=${#section_titles[@]}

    if (( section_count == 0 )); then
        echo "Tidak ada episode yang ditemukan."
        rm -f "$episodes_file"
        return 1
    fi

    # --------------------------------------------------
    # Section menu
    # --------------------------------------------------

    while true; do

        clear

        echo "=========================================="
        echo " $selected_anime"
        echo "=========================================="
        echo

        for ((i = 0; i < section_count; i++)); do
            printf "[%2d] %-30s %s\n" \
                "$((i + 1))" \
                "${section_titles[$i]}" \
                "${section_ranges[$i]}"
        done

        echo
        echo "[q] Keluar"
        echo

        printf "Pilih section: "
        read -r section_choice

        [[ "$section_choice" == "q" ]] && break

        if ! [[ "$section_choice" =~ ^[0-9]+$ ]] ||
           (( section_choice < 1 || section_choice > section_count )); then
            echo "Pilihan tidak valid."
            sleep 1
            continue
        fi

        local section_index=$((section_choice - 1))

        # --------------------------------------------------
        # Extract selected section
        # --------------------------------------------------

        local section_file
        section_file=$(mktemp)

        jq \
            ".data.sections[$section_index].episodes // []" \
            "$episodes_file" \
            > "$section_file"

        local episode_count
        episode_count=$(jq 'length' "$section_file")

        if (( episode_count == 0 )); then
            echo "Section ini tidak memiliki episode."
            rm -f "$section_file"
            sleep 1
            continue
        fi

        # --------------------------------------------------
        # Pagination
        # --------------------------------------------------

        local page=0
        local per_page=20
        local total_pages=$(( (episode_count + per_page - 1) / per_page ))

        while true; do

            clear

            echo "=========================================="
            echo " $selected_anime"
            echo " ${section_titles[$section_index]} | ${section_ranges[$section_index]}"
            echo "=========================================="
            echo

            local start=$((page * per_page))
            local end=$((start + per_page))

            if (( end > episode_count )); then
                end=$episode_count
            fi

            local display_index
            local jq_index

            local ep_short
            local ep_title
            local ep_id

            for ((jq_index = start; jq_index < end; jq_index++)); do

    display_index=$((jq_index - start + 1))

    ep_short=$(jq -r ".[$jq_index].short_title_display // \"Episode\"" "$section_file")
    ep_title=$(jq -r ".[$jq_index].long_title_display // .[$jq_index].title_display // \"\"" "$section_file")
    ep_limit=$(jq -r ".[$jq_index].limit_text // \"\"" "$section_file")

    if [[ "$ep_limit" == "Premium" ]]; then
        printf "[%2d] %-7s %s [PREMIUM]\n" \
            "$display_index" \
            "$ep_short" \
            "$ep_title"
    else
        printf "[%2d] %-7s %s\n" \
            "$display_index" \
            "$ep_short" \
            "$ep_title"
    fi
done

            echo
            echo "Halaman $((page + 1))/$total_pages"
            echo

            if (( page > 0 )); then
                printf "[p] Previous"
            fi

            if (( page < total_pages - 1 )); then
                printf "  [n] Next"
            fi

            printf "  [b] Back  [q] Quit"

            echo
            echo

            printf "Pilih episode: "
            read -r episode_choice

            case "$episode_choice" in

                q)
                    rm -f "$section_file" "$episodes_file"
                    return 0
                    ;;

                b)
                    break
                    ;;

                n)
                    if (( page < total_pages - 1 )); then
                        ((page++))
                    fi
                    continue
                    ;;

                p)
                    if (( page > 0 )); then
                        ((page--))
                    fi
                    continue
                    ;;

            esac

            # --------------------------------------------------
            # Episode selection
            # --------------------------------------------------

            if ! [[ "$episode_choice" =~ ^[0-9]+$ ]]; then
                echo "Pilihan tidak valid."
                sleep 1
                continue
            fi

            if (( episode_choice < 1 || episode_choice > end - start )); then
                echo "Nomor episode tidak valid."
                sleep 1
                continue
            fi

            jq_index=$((start + episode_choice - 1))

            ep_short=$(
                jq -r \
                    ".[$jq_index].short_title_display // \"Episode\"" \
                    "$section_file"
            )

            ep_title=$(
                jq -r \
                    ".[$jq_index].long_title_display // .[$jq_index].title_display // \"\"" \
                    "$section_file"
            )

            ep_id=$(
                jq -r \
                    ".[$jq_index].episode_id" \
                    "$section_file"
            )

            ep_limit=$(
    jq -r \
        ".[$jq_index].limit_text // \"\"" \
        "$section_file"
)

            local final_url
            final_url="https://www.bilibili.tv/id/play/${selected_season_id}/${ep_id}"

           echo

if [[ "$ep_limit" == "Premium" ]]; then
    echo "Memutar: $ep_title [PREMIUM]"
    echo
    echo "This video requires a Bstation Premium subscription."
    echo "Your Bstation account must be logged in through Firefox."
    echo
    
else
    echo "Memutar: $ep_title..."
fi

echo

mpv \
    --ytdl-raw-options="cookies-from-browser=firefox" \
    --slang=id \
    "$final_url"

#return $? #hapus kalo terminal reuseable
        done

        rm -f "$section_file"

    done

    rm -f "$episodes_file"
}


# --------------------------------------------------
# Run directly
# --------------------------------------------------
#
# Jika file dijalankan:
#
#   ./bstation.sh "one piece"
#
# maka function bstation akan dipanggil.
#
# Jika file di-source:
#
#   source bstation.sh
#
# function bstation juga tersedia di shell.
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bstation "$@"
fi