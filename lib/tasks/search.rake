require 'pp'
require 'elasticsearch/rails/ha/tasks'

# example of running this in production (at heroku)
# % heroku run --size=2X rake search:index NEWRELIC_ENABLE=false NPROCS=2 BATCH=200 -a pop-up-archive
#
# add the FORCE=y option to nuke the whole index prior to re-building it
#
# to stage a tmp index while the production index continues to serve live requests:
#
# % heroku run --size=performance-m rake search:stage search:commit NEWRELIC_ENABLE=false NPROCS=6 BATCH=100 -a pop-up-archive
#

namespace :search do
  desc 're-index all items'
  task index: [:environment] do
    ENV['CLASS'] ||= 'Item'
    Rake::Task["elasticsearch:ha:import"].invoke
    Rake::Task["elasticsearch:ha:import"].reenable
  end

  desc 're-index all items, in parallel'
  task mindex: [:environment] do
    # back compat. same thing as 'index' task
    ENV['CLASS'] ||= 'Item'
    Rake::Task["elasticsearch:ha:import"].invoke
    Rake::Task["elasticsearch:ha:import"].reenable
  end

  desc 'commit the staged index to be the new index'
  task commit: [:environment] do
    ENV['CLASS'] ||= 'Item'
    Rake::Task["elasticsearch:ha:promote"].invoke
    Rake::Task["elasticsearch:ha:promote"].reenable
  end
end
