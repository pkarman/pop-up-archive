class OembedController < Api::V1::BaseController

  # we inherit from Api::V1::BaseController in order to use OAuth or Devise authn

  rescue_from ActiveRecord::RecordNotFound, :with => :not_found

  def show
    # :url param is required
    if !params[:url]
      render :json => { :error => "not found", :status => 404 }.to_json, :status => :not_found
      return
    end

    # must check authz of the asked-for URL
    cur_user = current_user_with_oauth

    # templates handle jsonp response, if necessary.
    @callback = params[:callback]

    # extract the asset from the url
    route_action = Rails.application.routes.recognize_path(params[:url])
    # Rails.logger.warn( route_action.inspect )
    if (route_action[:action] == 'tplayer') || (route_action[:action] == 'iframe')
      # set up instance vars based on :url
      @url        = params[:url]
      @embed      = true
      @file_id    = route_action[:file_id]
      @audio_file = AudioFile.find(@file_id)
      if !@audio_file
        render :json => { :error => "not found", :status => 404 }.to_json, :status => :not_found
        return
      end

      # check authz
      may_read    = true
      if !@audio_file.item.is_public
        logger.debug("private item");
        if cur_user
          ability = Ability.new(cur_user)
          if !ability.can?(:read, @audio_file.item)
            logger.warn("current_user may not read")
            may_read = false
          else
            logger.warn("current_user may read")
          end 
        else
          logger.warn("no current_user")
          may_read = false
        end 
      end
      if !may_read
        logger.warn("current_user #{cur_user.id} !may_read #{@audio_file.item_id}") if cur_user
        render :text => { :error => "permission denied", :status => 403 }.to_json, :status => 403 
        return
      end

      # authz ok, continue.
      @mp3        = @audio_file.public_url(extension: :mp3)
      #@ogg        = @audio_file.public_url(extension: :ogg)
      @transcript = @audio_file.best_transcript
      @title      = route_action[:title] || @audio_file.item.title
      @chunk_size = route_action[:chunk] || 30
      @start      = route_action[:start] || 0
      @end        = route_action[:end]   || false
      @height     = (params[:height]      || 400).to_i
      @width      = (params[:width]       || 800).to_i

      # path to html (rich) template partial
      if route_action[:action] == 'iframe'
        @partial_path = "oembed/iframe.html"
      else
        @partial_path = 'oembed/tplayer.html'
      end
      
      # response type for tplayer
      @type = "rich"

    else
      # no matching service
      render :json => { :error => "not found", :status => 404 }.to_json, :status => :not_found
      return
    end

    respond_to do |format|
      format.html {
        render :formats => [:html, :json], :content_type => "application/json"
      }
      format.json {
        render :formats => [:html, :json]
      }
      format.xml {
        render :formats => [:html, :xml]  # TODO
      }
      format.all {
        render :json => { :error => "Format not implemented", :status => 501 }.to_json, :status => 501
      }
    end

  end

end
