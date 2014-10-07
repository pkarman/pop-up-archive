module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    # Set up callbacks for updating the index on model changes
    #
    after_commit lambda { IndexerWorker.perform_async(:index,  self.class.to_s, self.id) },
      on: :create,
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.blank? }

    after_commit lambda { IndexerWorker.perform_async(:update, self.class.to_s, self.id) },
      on: :update,
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.blank? }

    after_commit lambda { IndexerWorker.perform_async(:delete, self.class.to_s, self.id) },
      on: :destroy,
      if: Proc.new { |item| item.respond_to?(:deleted_at) && !item.deleted_at.blank? }
    
    after_touch  lambda { IndexerWorker.perform_async(:update, self.class.to_s, self.id) },
      if: Proc.new { |item| item.respond_to?(:deleted_at) && item.deleted_at.blank? }
  end
end
