object nil
node :collections do
  collections.map do |collection|
    partial 'api/v1/collections/collection', object: collection, locals: { show_recent: true }
  end
end

