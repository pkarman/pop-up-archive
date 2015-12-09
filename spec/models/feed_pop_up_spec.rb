require 'spec_helper'

describe FeedPopUp do

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:feed_url) { 'file://'+Dir.pwd+'/spec/factories/files/feed-atom.xml' }


  it "should be constructed with dry_run option" do
    FeedPopUp.new.dry_run.should == false
    FeedPopUp.new(true).dry_run.should == true
  end

  it "should process a feed" do
    mock_feed = OpenStruct.new
    mock_feed.entries = []
    Feedjira::Feed.stub(:fetch_and_parse).and_return(mock_feed)
    collection = FactoryGirl.create :collection_private
    fpu = FeedPopUp.new(true)
    fpu.parse(feed_url, collection.id)
  end

  it "should process a real feed" do
    collection = FactoryGirl.create :collection_private
    FeedPopUp.update_from_feed(feed_url, collection.id).should eq 11
  end

  describe "add audio files" do

    before(:each) {
      @fpu = FeedPopUp.new(true)
      @item = FactoryGirl.create :item
      @audio = @fpu.add_audio_file(@item, "http://fake.prx.org/audio.mp3?foo=bar&amp;bar=foo", @item.collection)
    }

    it "adds audio files with entity encoded urls" do
      @audio.url.should eq "http://fake.prx.org/audio.mp3?foo=bar&bar=foo"
    end

    it "adds audio files with user same as collection creator" do
      @audio.user.should_not be_nil
      @audio.user.should eq @item.collection.creator
    end

  end

end
