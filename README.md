# focus-shell

A minimal bash script that blocks distracting sites via `/etc/hosts` for a set number of hours. Works on macOS and Linux.

## Usage

```
sudo focus start [hours]   # start a block (default 3h)
sudo focus add [hours]     # extend the current deadline (default +3h)
sudo focus stop            # unblock everything now
     focus status          # show time remaining and blocked sites
```

`hours` must be a whole number greater than 0.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sdi2200262/focus-shell/main/focus \
  -o /usr/local/bin/focus && chmod +x /usr/local/bin/focus
```

Or clone and symlink:

```bash
git clone https://github.com/sdi2200262/focus-shell.git
ln -s "$PWD/focus-shell/focus" /usr/local/bin/focus
```

## Blocked sites

Edit the `DOMAINS` array at the top of the script to customize. Defaults:

- Instagram, Reddit, LinkedIn, X/Twitter, Facebook, TikTok

## How it works

Appends a marked block to `/etc/hosts` that redirects the domains to `127.0.0.1`. A detached background process removes the block when the deadline expires. The deadline survives reboots — if the machine is off when the timer fires, the block is removed on the next `focus stop` or `focus start`.

## License

MIT
