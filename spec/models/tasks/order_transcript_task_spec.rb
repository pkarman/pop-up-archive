require 'spec_helper'

describe Tasks::OrderTranscriptTask do

  before { StripeMock.start }
  after { StripeMock.stop }

  before(:each) do
    @audio_file = FactoryGirl.create :audio_file
    @user = FactoryGirl.create :user
    @user.should_receive(:has_active_credit_card?).and_return(true)

    @task = Tasks::OrderTranscriptTask.new(owner: @audio_file, identifier: 'order_transcript', extras: {'user_id' => @user.id, 'omit_subtitles' => true } )
    @task.should_receive(:user).at_least(:once).and_return(@user)
    @task.should_receive(:create_video).once.and_return(Hashie::Mash.new({id: 'NEWVIDEO'}))
    @task.save!
  end

  it "should be valid with defaults" do
    task = Tasks::OrderTranscriptTask.new(owner: @audio_file, identifier: 'order_transcript', extras: {'user_id' => @user.id, 'omit_subtitles' => true } )
    task.owner.should eq @audio_file
    task.identifier.should eq 'order_transcript'
    task.should be_valid
  end

end
