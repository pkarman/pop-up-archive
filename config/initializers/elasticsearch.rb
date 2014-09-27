require 'elasticsearch/model'

es_url = 'http://localhost:9200'
if ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
  es_url = ENV['BONSAI_URL'] || ENV['ELASTICSEARCH_URL']
end
Elasticsearch::Model.client = Elasticsearch::Client.new({
  url: es_url,
  log: true,
  trace: true
})

if Rails.env.development?
  logger = Logger.new('log/elasticsearch.log')
  logger.level =  Logger::DEBUG
end

Elasticsearch::Model.client.transport.logger = tracer

puts "Starting Elasticsearch model with server #{es_url}"
