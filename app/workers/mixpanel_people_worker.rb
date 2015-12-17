# encoding: utf-8
require 'mixpanel-ruby'

class MixpanelPeopleWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10, backtrace: true

  def perform(user_id, attrs)
    begin
      tracker = Mixpanel::Tracker.new(ENV['MIXPANEL_PROJECT'])
      tracker.people.set(user_id, attrs, 0, {'$ignore_time' => 'true'})
    rescue => e
      raise e
    end
    true
  end

end
