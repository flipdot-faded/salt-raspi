canbus:
  user.present:
    - name: canbus
    - home: /home/canbus/
    - groups: 
      - canbus
      - dialout

  pkg.installed:
    - pkgs:
      - python3
      - python3-pip
      - python3-virtualenv
      - git

  git.latest:
    - name: https://github.com/flipdot/Spacecontrol
    - target: /home/canbus/Spacecontrol

  file.directory:
    - name: /home/canbus/Spacecontrol/
    - user: canbus
    - group: users
    - mode: 755
    - makedirs: True
    - recurse:
      - user
      - group


/boot/cmdline.txt:
  file.replace:
    - pattern: "console=serial0,115200 "
    - repl: ""



canbus_server:  
  pip.installed:
    - bin_env: pip3
    - requirements: /home/canbus/Spacecontrol/CanBusServer/requirements.txt
