#!/usr/bin/env bash

# fail fast
set -e

export RACK_ENV=$SVC_ENV
export APP_ENV=$SVC_ENV
export CLOUDTRUTH_ENVIRONMENT=${CLOUDTRUTH_ENVIRONMENT:-${SVC_ENV}}

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

  maybe_cloudtruth=""
  if [[ "$SVC_ENV" != "local" ]]; then
    maybe_cloudtruth="cloudtruth run --"
  fi

  exec $maybe_cloudtruth bundle exec ruby server.rb -o 0.0.0.0 -p $SVC_PORT
}
export -f start_app

function update_cloudtruth_rb {
  echo "Updating params in cloudtruth project '${CLOUDTRUTH_PROJECT}'"

  ruby  <(
  cat <<-EOF
    puts "Updating cloudtruth params for project '#{ENV['CLOUDTRUTH_PROJECT']}' in environment '#{ENV['CLOUDTRUTH_ENVIRONMENT']}'"

    existing_params = %x(cloudtruth param ls | grep -v "No parameters found").lines(chomp: true)
    local_params_data = File.read(".env").lines(chomp: true).reject{|l| l=~ /^\s*#/ }
    local_params = Hash[local_params_data.collect {|l| l.split(/\s*=\s*/) }]
    new_params = local_params.keys - existing_params
    new_params.each do |param|
      value = local_params[param]
      puts "Adding new param '#{param}=#{value}' to cloudtruth"
      system("cloudtruth param set '#{param}' -v '#{value}'")
    end
EOF
  )
}

function update_cloudtruth {
  echo "Updating cloudtruth params for project '${CLOUDTRUTH_PROJECT}' in environment '${CLOUDTRUTH_ENVIRONMENT}'"

  declare existing_params=($(cloudtruth param ls | grep -v "No parameters found"))
  declare local_params=($(awk -F= '!/[[:space:]]*#/ {print $1}' .env))
  declare new_params=($(printf '%s\n' "${existing_params[@]}" "${existing_params[@]}" "${local_params[@]}" | sort | uniq -u))
  for param in ${new_params[@]}; do
    value=$(awk -F= "/^${param}=/ {print \$2}" .env)
    echo "Adding new param '${param}=${value}' to cloudtruth"
    cloudtruth param set "$param" -v "$value"
  done
}
export -f update_cloudtruth

action=$1; shift
setup_env

case $action in

  app)
    app_init
    start_app
  ;;

  ctsync)
    update_cloudtruth
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
