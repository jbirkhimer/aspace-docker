#!/bin/bash

BASEDIR=$(dirname "$0")/../

export GEM_HOME="$BASEDIR/gems"
export GEM_PATH="$BASEDIR/gems"

cd "$BASEDIR"

java -Xmx2048m -cp bin/jruby-complete-9.1.0.0.jar org.jruby.Main -S gem install bundler

java -Xmx2048m -cp bin/jruby-complete-9.1.0.0.jar org.jruby.Main gems/bin/bundle install
