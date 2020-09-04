#!/usr/bin/env bash

# fail fast
set -e

export RACK_ENV=$SVC_ENV
export APP_ENV=$SVC_ENV

function setup_env {
  if [[ -z $AWS_DEFAULT_REGION ]]; then
    export AVAILABILITY_ZONE="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    export AWS_DEFAULT_REGION="$(echo $AVAILABILITY_ZONE | sed -e 's/[a-z]$//')"
  fi
}
export -f setup_env

function app_init {
  # Run bundler if needed - useful in dev
  if [[ "$SVC_ENV" == "development" ]]; then
    bundle check || bundle install
  fi
}
export -f app_init

function start_app {
  echo "Starting app"
  exec bundle exec ruby server.rb -o 0.0.0.0 -p $SVC_PORT
}
export -f start_app

action=$1; shift
setup_env

case $action in

  app)
    app_init
    start_app
  ;;

  bash)
    if [ "$#" -eq 0 ]; then
      bash_args=( -il )
    else
      bash_args=( "$@" )
    fi
    exec bash "${bash_args[@]}"
  ;;

  exec)
    exec "$@"
  ;;

  *)
    echo "Unknown action: '$action', defaulting to exec"
    exec $action "$@"
  ;;

esac
