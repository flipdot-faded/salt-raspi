spacebot:
  user.present:
    - name: sopel
    - home: /home/sopel/

  pkg.installed:
    - pkgs:
      - python3
      - python3-pip
      - git
  pip.installed:
    - bin_env: pip3
    - name: sopel

  git.latest:
    - name: https://github.com/flipdot/sopel-modules/
    - target: /home/sopel/.sopel/modules/

  file.directory:
    - name: /home/sopel/.sopel/
    - user: sopel
    - group: users
    - mode: 755
    - makedirs: True
    - recurse:
      - user
      - group

spacebot_spacestatus:  
  pip.installed:
    - bin_env: pip3
    - requirements: /home/sopel/.sopel/modules/spacestatus/requirements.txt

spacebot_github:
  pip.installed:
    - bin_env: pip3
    - requirements: /home/sopel/.sopel/modules/github/requirements.txt

spacebot_chanlogs_display:
  pip.installed:
    - bin_env: pip3
    - requirements: /home/sopel/.sopel/modules/chanlogs-display/requirements.txt
