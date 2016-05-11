matchbox:
  pkg.installed

# Boot to X
/etc/systemd/system/default.target:
  file.symlink:
    - target: /lib/systemd/system/graphical.target
