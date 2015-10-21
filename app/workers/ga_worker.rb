# encoding: utf-8
require 'staccato'

class GAWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'google_analytics', retry: 10, backtrace: true

  def perform(meth, args)
    begin
      tracker = Staccato.tracker(ENV['GOOGLE_ANALYTICS_KEY'], 'audiosearch-web')
      tracker.send meth.to_sym, args
    rescue => e
      raise e
    end
  end

end
