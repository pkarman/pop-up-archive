# encoding: utf-8
require 'mixpanel-ruby'

class MixpanelWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10, backtrace: true

  # :nocov:
  def perform(distinct_id, event_name, event_args)
    begin
      tracker = Mixpanel::Tracker.new(ENV['MIXPANEL_PROJECT'])
      tracker.track(distinct_id, event_name, event_args)
    rescue => e
      raise e
    end
    true
  end
  # :nocov:

end
