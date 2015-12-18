class ApplicationController < ActionController::Base
  force_ssl if: :ssl_configured?
  before_filter :check_adobe

  protect_from_forgery with: :null_session, only: Proc.new { |c| c.request.format.json? }

  #decent_configuration do
  #  strategy DecentExposure::StrongParametersStrategy
  #end

  # :nocov:
  rescue_from CanCan::AccessDenied do |exception|
    flash[:error] = exception.message
    redirect_to root_url
  end
  # :nocov:

  # :nocov:
  def authenticate_superadmin_user!
    authenticate_user!
    unless current_user.super_admin?
      flash[:alert] = "Unauthorized Access!"
      redirect_to root_path
    end
  end
  # :nocov:

  def not_found
    respond_to do |format|
      # TODO render app 404 rather than generic 
      format.html { render :file => File.join(Rails.root, 'public', '404'), :formats => [:html], :status => :not_found }

      format.json { render :text => { :error => "not found", :status => 404 }.to_json, :status => :not_found }
      format.xml  { render :text => '<error><msg>not found</msg><status>404</status></error>', :status => :not_found }
      format.txt  { render :text => 'not found', :status => :not_found }
      format.srt  { render :text => 'not found', :status => :not_found }
    end

  end

  def check_adobe
    if params[:adobe] == "true"
      session[:adobe] = true
    elsif params[:adobe] == "false"
      session[:adobe] = false
    end
  end
  
  def invite
    @mail = params[:mail_details]
    MyMailer.mailto(@mail['subject'], @mail['body'], @mail['to']).deliver_now

    render nothing: true
  end

  private

  def ssl_configured?
    !Rails.env.development? && !Rails.env.test?
  end

end
