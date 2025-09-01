#!/bin/bash

if [ `hostname` = 'eco' ]; then
  export SECRET_KEY_BASE=H4xFWPpaiey9bQw6W8YZPjTtBFQ9wrjUxGiVv5AnM+ST7U2Po3auFfllMDW+Z9aK
  export MIX_ENV=prod
  export PORT=4403
  export PHX_SERVER=true
  export DOMAIN=128.140.47.184
  export RELEASE_NAME=sync_test
  export DB_PASSWORD=change_me

  # . $HOME/.asdf/asdf.sh
  cd sync_test 
  git pull
	mix deps.get --only prod
	mix do compile, assets.setup, assets.deploy, ecto.setup
  mix phx.gen.release
  MIX_ENV=prod mix release --overwrite
  sudo systemctl restart sync_test.service

  sudo systemctl status sync_test.service
  sleep 3
  sudo systemctl status sync_test.service




else
  scp host_sync_test.sh b_eco_staging:
  ssh b_eco_staging "bash -l host_sync_test.sh"
fi


