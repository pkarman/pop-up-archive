# encoding: utf-8

class ProcessTaskWorker
  include Sidekiq::Worker

  sidekiq_options :retry => 25, unique: :until_and_while_executing

  def perform(task_id)
    ActiveRecord::Base.connection_pool.with_connection do
      begin
        task = Task.find_by_id(task_id)
        task.process if task
      rescue StandardError => err
        logger.warn "ProcessTaskWorker: task: #{task_id}, err: #{err.message}\n\t#{err.backtrace.join("\n\t")}"
        raise err
      end
      true
    end
  end

end
