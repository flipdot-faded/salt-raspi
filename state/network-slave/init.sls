# TODO
# mapping to /usr/bin/network-slave
# config to /home/tv/.config/network-slave/config

python3:
  pkg.installed

https://github.com/flipdot/network-slave.git:
  git.latest:
    - target: /opt/network-slave
    - force_fetch: True
    - force_reset: True
    - user: root

/usr/bin/network-slave:
  file.symlink:
    - target: /opt/network-slave/network-slave.py
