class Api::V1::OrganizationsController < Api::V1::BaseController
  expose(:organization)

  authorize_resource decent_exposure: true

  def show
    respond_with :api, organization
  end

  def member
    org        = organization
    user_email = params[:email]
    user = User.find_by_email(user_email)
    if !user or !org
      self.not_found and return
    end 

    if org.invite_user(user)
      respond_to do |format|
        format.html { redirect_to root_url + 'organization' }
        format.json { render :text => { :msg => "invite sent", :status => 200 }.to_json, :status => 200 }
      end 
    else
      # error could be any number of things. Do we care enough about the actual reason to return it?
      respond_to do |format|
        format.html { render :file => File.join(Rails.root, 'public', '500'), :formats => [:html], :status => 501 }
        format.json { render :text => { :error => "failed to send invite", :status => 501 }.to_json, :status => 501 }
      end 
    end 
  end

  def delete_member
    user = User.find(params[:user_id])
    if organization.delete_user(user)
      respond_to do |format|
        format.html { redirect_to root_url + 'organization' }
        format.json { render :text => { :msg => "user deleted", :status => 200 }.to_json, :status => 200 }
      end 
    else
      # error could be any number of things. Do we care enough about the actual reason to return it?
      respond_to do |format|
        format.html { render :file => File.join(Rails.root, 'public', '500'), :formats => [:html], :status => 501 }
        format.json { render :text => { :error => "failed to delete member", :status => 501 }.to_json, :status => 501 }
      end 
    end
  end

end
