# Sudoers Setup for Passwordless Route Commands

## Step 1 — Open the sudoers editor

```bash
sudo visudo
```

It will ask for your Mac password, then open the file in the Terminal editor.

---

## Step 2 — Navigate to the bottom of the file

Press the `End` key or use the arrow keys to scroll to the very last line.

---

## Step 3 — Add this line

Type it exactly as shown:

```
%admin ALL=(ALL) NOPASSWD: /sbin/route
```

---

## Step 4 — Save and exit

> This is the part that trips people up since it's not a normal text editor.

Press `Ctrl + X` → then press `Y` to confirm save → then press `Enter` to keep the filename.

`visudo` will validate the syntax before saving, so if you made a typo it will warn you rather than corrupting the file.

---

## Verify it worked

```bash
sudo route -n add 1.2.3.4 192.168.1.1
```

If it runs without asking for a password, you're good. Clean it up after:

```bash
sudo route -n delete 1.2.3.4
```

---

## If your editor is vim instead of nano

If you see `~` characters on empty lines, your Terminal opened `visudo` in **vim**. The commands are different:

| Action | Command |
|--------|---------|
| Go to end of file | `Shift + G` |
| Open a new line | `o` |
| Type the rule | _(type normally)_ |
| Exit insert mode | `Esc` |
| Save and quit | `:wq` then `Enter` |

---

## Vim command reference

Vim has a "command mode" — press `:` first to enter it, then type the command.

| Command | Meaning | What it does |
|---------|---------|--------------|
| `:wq` | **w**rite + **q**uit | Save and exit |
| `:q` | **q**uit | Quit (only works if no unsaved changes) |
| `:q!` | **q**uit force | Exit without saving, discards all changes |
| `:w` | **w**rite | Save only, stay in the editor |

> The `!` in vim generally means "force it / I'm sure" — use it when vim refuses to quit due to unsaved changes.
