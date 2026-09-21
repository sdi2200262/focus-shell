# focus-shell

A minimal bash script that blocks distracting websites via `/etc/hosts`. Works on macOS and Linux.

Appends a marked block to `/etc/hosts` redirecting domains to `127.0.0.1`. A lightweight background process manages schedule windows, timer expirations, and breaks. Runs without external dependencies on both macOS and Linux.

## Usage

```text
focus status                                           # show state, time left, and blocked sites
sudo focus start [duration]                            # block immediately (default: 3h)
sudo focus add [duration]                              # extend deadline (default: 1h)
sudo focus schedule {--allow|--block} <range> [--days] # recurring schedule (e.g. --allow 9pm-11pm)
sudo focus break [duration]                            # pause blocking (default: 30m)
sudo focus resume                                      # end break early, resume blocking
sudo focus stop                                        # unblock everything now
```

## Formats

- **Duration**: Whole numbers with `h` or `m` (e.g. `30m`, `2h`, `1h30m`).
- **Scheudle Time**: 12-hour local time with am/pm (e.g. `9am`, `5pm`, `12am`, `12pm`, `8:30am`, `9:15pm`).

## Install

Place the `focus` executable somewhere in your `PATH` (e.g. `~/.local/bin` or `/usr/local/bin`):

```bash
# Clone and symlink:
ln -s "$PWD/focus" ~/.local/bin/focus

# Or download directly:
curl -fsSL https://raw.githubusercontent.com/sdi2200262/focus-shell/main/focus \
  -o /usr/local/bin/focus && chmod +x /usr/local/bin/focus
```

## Blocked sites

Edit the `DOMAINS` array at the top of the script to customize. Defaults:
- Instagram, Reddit, LinkedIn, X/Twitter, Facebook, TikTok, YouTube

## Tests

Run the isolated test suite:

```bash
bash test/test_focus.sh
```

## License

MIT
