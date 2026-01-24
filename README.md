# dotfiles

This repository contains my personal dotfiles. Additionally I also added some config files for tools that I use, so I can restore everything after the zombie apocalipse has ended.

## Windows

> [!TIP]
> Ensure that execution policy is right before running anything:
> ```ps1
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

Run the following to setup everything on windows terminal:

```ps1
iex ((iwr "https://raw.githubusercontent.com/Dovyski/dotfiles/main/windows.ps1").Content)
```

## Linux

Run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Dovyski/dotfiles/main/ubuntu.sh)"
```
## References

The files I use are based on the following sources:

- https://tldp.org/LDP/abs/html/sample-bashrc.html
- https://misc.flogisoft.com/bash/tip_colors_and_formatting
