# Bstation-CLI

A lightweight and Simple function for searching and watching anime from **Bstation (Bilibili TV)** directly from the terminal using `mpv`.

## Features

- 🔎 Anime search
- 📚 Browse Anime by section/arc navigation
- 📄 Episode pagination
- ▶️ Play a specific episode directly
- 🇮🇩 Automatic Indonesian subtitle selection
- 🍪 Uses Firefox cookies for Bstation authentication
- 🧰 Works from Bash and can be launched from other shells such as Zsh
- 🎬 MPV playback
- 🔢 Direct episode selection, e.g. `bstation "one piece" 500`

---

## Requirements

The following programs are required:

| Dependency | Purpose                                      |
| ---------- | -------------------------------------------- |
| `curl`     | Request Bstation API                         |
| `jq`       | Parse JSON responses                         |
| `mpv`      | Play Bstation videos                         |
| `yt-dlp`   | Extract Bstation video/subtitle streams      |
| `Firefox`  | Provides cookies for registered-user content |

### Verify dependencies

You can check that the required commands are available:

```bash
bash --version
curl --version
jq --version
mpv --version
yt-dlp --version
```

Also make sure Firefox is installed and you are logged in to Bstation.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/FeriDwiSptra/bstation-cli.git
```

Enter the directory:

```bash
cd bstation-cli
```

Make the script executable:

```bash
chmod +x bstation.sh
```

You can now run the program directly:

```bash
./bstation.sh "one piece"
```

---

## Usage

```bash
./bstation.sh "one piece"
```

The script will display the search results:

```text
=== Hasil Pencarian ===

[1] One Piece
[2] One Piece Movie
[3] One Piece Special

Pilih anime [1-3] (q untuk keluar):
```

Choose the anime by entering its number.

---

### Browse episodes

After selecting an anime, the available sections / arcs will be displayed:

```text
==========================================
 One Piece
==========================================

[ 1] Luffy dan Kru                  1-30
[ 2] Taman Arlong                   31-45
[ 3] Kota nakal                     46-61
[ 4] Baroque Works                  62-77
...
```

Select a section to browse its episodes.

---

### Episode pagination

Episodes are displayed 20 at a time.

```text
[ 1] E1      I'm Luffy! ...
[ 2] E2      The Great Swordsman ...
[ 3] E3      Morgan versus Luffy ...
...
[20] E20     The Famous Cook ...

Halaman 1/2

[n] Next  [b] Back  [q] Quit
```

Available controls:

| Key    | Action               |
| ------ | -------------------- |
| `1-20` | Select episode       |
| `n`    | Next page            |
| `p`    | Previous page        |
| `b`    | Back to section list |
| `q`    | Quit                 |

---

## Play a specific episode

You can skip the episode browser and directly play an episode:

```bash
./bstation.sh "one piece" 500
```

This searches for episode `E500` and plays it directly.

Another example:

```bash
./bstation.sh "naruto" 220
```

---

## Firefox Cookies

Bstation may require an authenticated session to play certain content.

The script uses `yt-dlp` with:

```text
--cookies-from-browser=firefox
```

This allows `yt-dlp` to use the cookies from your Firefox profile.

Make sure:

1. Firefox is installed.
2. You are logged in to Bstation in Firefox.
3. Firefox is not using a profile that `yt-dlp` cannot access.

You can test whether `yt-dlp` can access Bstation using:

```bash
yt-dlp \
    --cookies-from-browser firefox \
    --list-subs \
    "https://www.bilibili.tv/id/play/SEASON_ID/EPISODE_ID"
```

Replace `SEASON_ID` and `EPISODE_ID` with a valid Bstation URL.

---

## Running from Zsh

Although this project is written in Bash, you can run it from a Zsh terminal.

For example:

```zsh
./bstation.sh "one piece"
```

The following line at the beginning of the script tells the operating system to use Bash:

```bash
#!/usr/bin/env bash
```

Therefore, you do not need to change your default shell to Bash.

### Important

Do not use:

```zsh
source bstation.sh
```

from Zsh.

The script should be executed:

```zsh
./bstation.sh "one piece"
```

because the script is designed to run under Bash.

---

## Optional: Install as a command

If you want to use:

```bash
bstation "one piece"
```

instead of:

```bash
./bstation.sh "one piece"
```

you can create a local executable directory:

```bash
mkdir -p ~/.local/bin
```

Create a symbolic link:

```bash
ln -s "$(realpath bstation.sh)" ~/.local/bin/bstation
```

Make sure `~/.local/bin` is included in your `PATH`.

Check:

```bash
echo "$PATH"
```

Then you can run:

```bash
bstation "one piece"
```

from anywhere.

---

# Notes

- Bstation's API is an internal web API and may change without notice.
- Availability of videos and subtitles depends on Bstation.
- Some videos may require a logged-in Bstation account.
- Subtitle availability can vary between episodes.
- The function currently assumes Firefox is the browser used for Bstation authentication.
- This project is intended as a terminal convenience tool and is not affiliated with Bstation or Bilibili.
- If video has a [Premium] Label, it Cannot be Played Unless Your Bstation Account has a Premium Subscription.

---

## Disclaimer

This project is an unofficial third-party CLI tool.

It is not affiliated with, endorsed by, or officially supported by Bstation or Bilibili.

The project depends on Bstation's web API and may stop working if the API, authentication system, or website changes.

Use this project in accordance with Bstation's terms of service and applicable laws.

---

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.
