class Users::RegistrationsController < Devise::RegistrationsController

  before_filter :update_sign_up_filter
  require 'mixpanel-ruby'

  def create
    build_resource(sign_up_params)

    if resource.save
      yield resource if block_given?
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        notify_user
        respond_with resource, :location => '/collections'
        send_to_mixpanel
      else
        expire_data_after_sign_in!
        respond_with resource, :location => after_inactive_sign_up_path_for(resource)
      end
    else
      if existing_user = User.find_by_email(resource.email)
        message = ["Sorry, another account with that email address exists.<br />You can use a different email or"]
        if existing_user.provider.present?
          message << "try logging in with #{existing_user.provider.titleize}."
        else
          message << "reset your password below."
        end
        resource.email = nil
        resource.name = nil
      else
        message = ["There was a problem saving your account."].concat(resource.errors.full_messages)
      end
      flash[:notice] = message.join('<br />')
      clean_up_passwords resource
      respond_with resource
    end
  end

  protected

  def build_resource(*args)
    session[:plan_id] = params[:plan_id] if params[:plan_id].present?    
    session[:plan_id] = "premium_community" if params[:plan_id] == "community"
    session[:card_token] = params[:card_token] if params[:card_token].present?
    session[:offer_code] = params[:offer_code] if params[:offer_code].present?
    super

  end

  def update_sign_up_filter
    devise_parameter_sanitizer.for(:sign_up) do |default_params|
      default_params.permit(:name, :password, :password_confirmation, :email, :provider, :uid)
    end
  end

  def sign_up(resource_name, resource)
    set_card_and_plan(resource)
    super
  end

  expose(:plan){ get_plan }
  expose(:card_available?) { get_card_available || offer_code == 'radiorace' }
  expose(:offer_code) { session[:offer_code] }

  def get_plan
    if plan_id.present?
      SubscriptionPlanCached.find(plan_id)
    else
      SubscriptionPlanCached.community
    end
  end

  def get_card_available
    !!session[:card_token]
  end

  def plan_id
    # session[:plan_id] = "premium_community" if params[:plan_id] == "community" || session[:plan_id] == "community"
    session[:plan_id] = (params[:plan_id] || session[:plan_id])
  end

  def set_card_and_plan(user)
    if session[:card_token].present?
      card_token = session.delete(:card_token)
      user.update_card!(card_token)
    end
    if session[:plan_id].present?
      plan_id = session.delete(:plan_id)
      user.subscribe!(SubscriptionPlanCached.find(plan_id), session.delete(:offer_code))
      return unless Rails.env == 'production'
      gb = Gibbon::API.new
      gb.lists.subscribe(:id => "39650ec21b",
                   :email => {:email=> user.email},
                   :merge_vars =>
                     nil,
                   :update_existing => "true",
                   :double_optin => "false",
                   :replace_interests => "false",
                   :send_welcome => "false")
      gb.lists.subscribe(:id => "34d17df69f",
                   :email => {:email=> user.email},
                   :merge_vars =>
                     nil,
                   :update_existing => "true",
                   :double_optin => "false",
                   :replace_interests => "false",
                   :send_welcome => "false")
    end
  end
  
  def notify_user
    TranscriptCompleteMailer.new_user_email(@user).deliver
  end
  
  def send_to_mixpanel
    begin
      tracker = Mixpanel::Tracker.new(ENV['MIXPANEL_PROJECT'])
      mp_cookie = JSON.parse(cookies["mp_"+ENV['MIXPANEL_PROJECT']+"_mixpanel"])
      # logger.debug("mixpanel cookie" + mp_cookie['distinct_id'])
      tracker.alias(@user.email, mp_cookie["distinct_id"])    
      tracker.people.set(@user.email, {
        '$name' => @user.name,
        '$email' => @user.email,
        '$plan' => @user.plan_id,
      }, ip=request.remote_ip)
      tracker.track(@user.email,  'Registered')
    rescue
      logger.error "Mixpanel registration error."
    end
  end

end
