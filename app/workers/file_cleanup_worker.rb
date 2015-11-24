class FileCleanupWorker 
  def self.find_file(file_id)
    f=AudioFile.find(file_id)
    
      begin
        response=HTTParty.head(f.original_file_url, follow_redirects: true, maintain_method_across_redirects: true, limit: 15)
        case response.code
            when 200
              puts "Found #{f.id}"
              return response.code
            when 403
              puts "Forbidden"
              return response.code
            when 404 || 401
              puts "Not found #{response.code}: #{f.id} #{f.original_file_url}"
              return response.code
        end
      rescue => e
            return "unknown"
        end
  end
end