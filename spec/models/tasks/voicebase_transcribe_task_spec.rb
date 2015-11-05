require 'spec_helper'

describe Tasks::VoicebaseTranscribeTask do

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:user) { FactoryGirl.create :user }
  let(:audio_file) { FactoryGirl.create :audio_file_private, user_id: user.id }
  let(:task) { Tasks::VoicebaseTranscribeTask.new(owner: audio_file, extras: {'user_id' => user.id}) }

  let(:response) {
    m = Hashie::Mash.new
    m.body = { 'transcript' =>  {
 "name"=>"latest",
 "revision"=>"dfbb21ac-ac93-426a-b14a-d9005e7f66d7",
 "type"=>"machine",
 "engine"=>"standard",
 "formats"=>["json", "text", "srt"],
 "words"=>
  [{"p"=>1, "c"=>0.904, "s"=>9, "e"=>2403, "w"=>"we"},
   {"p"=>2, "c"=>0.863, "s"=>2403, "e"=>2743, "w"=>"people"},
   {"p"=>3, "c"=>0.94, "s"=>2743, "e"=>2862, "w"=>"of"},
   {"p"=>4, "c"=>0.979, "s"=>2862, "e"=>2982, "w"=>"the"},
   {"p"=>5, "c"=>0.984, "s"=>2982, "e"=>3900, "w"=>"United"},
   {"p"=>6, "c"=>0.984, "s"=>2982, "e"=>3900, "w"=>"States"},
   {"p"=>7, "c"=>65.535, "s"=>3900, "e"=>3910, "w"=>",", "m"=>"punc"},
   {"p"=>8, "c"=>0.938, "s"=>3910, "e"=>4000, "w"=>"in"},
   {"p"=>9, "c"=>0.959, "s"=>4000, "e"=>4279, "w"=>"order"},
   {"p"=>10, "c"=>0.967, "s"=>4279, "e"=>4379, "w"=>"to"},
   {"p"=>11, "c"=>0.953, "s"=>4379, "e"=>4858, "w"=>"form"},
   {"p"=>12, "c"=>0.948, "s"=>4858, "e"=>4918, "w"=>"a"},
   {"p"=>13, "c"=>0.964, "s"=>4918, "e"=>5097, "w"=>"more"},
   {"p"=>14, "c"=>0.983, "s"=>5097, "e"=>5656, "w"=>"perfect"},
   {"p"=>15, "c"=>0.933, "s"=>5656, "e"=>6295, "w"=>"Union"},
   {"p"=>16, "c"=>65.535, "s"=>6295, "e"=>6305, "w"=>",", "m"=>"punc"},
   {"p"=>17, "c"=>0.985, "s"=>6305, "e"=>6853, "w"=>"establish"},
   {"p"=>18, "c"=>0.976, "s"=>6853, "e"=>7991, "w"=>"Justice"},
   {"p"=>19, "c"=>65.535, "s"=>7991, "e"=>8000, "w"=>",", "m"=>"punc"},
   {"p"=>20, "c"=>0.992, "s"=>8000, "e"=>8450, "w"=>"insure"},
   {"p"=>21, "c"=>0.995, "s"=>8450, "e"=>8928, "w"=>"domestic"},
   {"p"=>22, "c"=>0.996, "s"=>8928, "e"=>10205, "w"=>"tranquility"},
   {"p"=>23, "c"=>65.535, "s"=>10205, "e"=>10215, "w"=>",", "m"=>"punc"},
   {"p"=>24, "c"=>0.988, "s"=>10215, "e"=>10724, "w"=>"provide"},
   {"p"=>25, "c"=>0.968, "s"=>10724, "e"=>10844, "w"=>"for"},
   {"p"=>26, "c"=>0.967, "s"=>10844, "e"=>10924, "w"=>"the"},
   {"p"=>27, "c"=>0.977, "s"=>10924, "e"=>11263, "w"=>"common"},
   {"p"=>28, "c"=>0.982, "s"=>11263, "e"=>12301, "w"=>"defense"},
   {"p"=>29, "c"=>65.535, "s"=>12301, "e"=>12311, "w"=>",", "m"=>"punc"},
   {"p"=>30, "c"=>0.982, "s"=>12311, "e"=>12680, "w"=>"promote"},
   {"p"=>31, "c"=>0.984, "s"=>12680, "e"=>12800, "w"=>"the"},
   {"p"=>32, "c"=>0.989, "s"=>12800, "e"=>13159, "w"=>"general"},
   {"p"=>33, "c"=>0.983, "s"=>13159, "e"=>14236, "w"=>"welfare"},
   {"p"=>34, "c"=>0.942, "s"=>14236, "e"=>14396, "w"=>"and"},
   {"p"=>35, "c"=>0.939, "s"=>14396, "e"=>14735, "w"=>"secure"},
   {"p"=>36, "c"=>0.97, "s"=>14735, "e"=>14855, "w"=>"the"},
   {"p"=>37, "c"=>0.982, "s"=>14855, "e"=>15374, "w"=>"blessings"},
   {"p"=>38, "c"=>0.976, "s"=>15374, "e"=>15473, "w"=>"of"},
   {"p"=>39, "c"=>0.974, "s"=>15473, "e"=>15892, "w"=>"liberty"},
   {"p"=>40, "c"=>0.978, "s"=>15892, "e"=>15992, "w"=>"to"},
   {"p"=>41, "c"=>0.981, "s"=>15992, "e"=>16631, "w"=>"ourselves"},
   {"p"=>42, "c"=>0.957, "s"=>16631, "e"=>16691, "w"=>"and"},
   {"p"=>43, "c"=>0.975, "s"=>16691, "e"=>16830, "w"=>"our"},
   {"p"=>44, "c"=>0.988, "s"=>16830, "e"=>18147, "w"=>"posterity"},
   {"p"=>45, "c"=>65.535, "s"=>18147, "e"=>18157, "w"=>",", "m"=>"punc"},
   {"p"=>46, "c"=>0.982, "s"=>18157, "e"=>18347, "w"=>"do"},
   {"p"=>47, "c"=>0.982, "s"=>18347, "e"=>18806, "w"=>"ordain"},
   {"p"=>48, "c"=>0.985, "s"=>18806, "e"=>18945, "w"=>"and"},
   {"p"=>49, "c"=>0.992, "s"=>18945, "e"=>19524, "w"=>"establish"},
   {"p"=>50, "c"=>0.993, "s"=>19524, "e"=>19763, "w"=>"this"},
   {"p"=>51, "c"=>0.994, "s"=>19763, "e"=>20781, "w"=>"Constitution"},
   {"p"=>52, "c"=>0.983, "s"=>20781, "e"=>20901, "w"=>"for"},
   {"p"=>53, "c"=>0.99, "s"=>20901, "e"=>21001, "w"=>"the"},
   {"p"=>54, "c"=>0.994, "s"=>21001, "e"=>23255, "w"=>"United"},
   {"p"=>55, "c"=>0.994, "s"=>21001, "e"=>23255, "w"=>"States"},
   {"p"=>56, "c"=>0.994, "s"=>21001, "e"=>23255, "w"=>"of"},
   {"p"=>57, "c"=>0.994, "s"=>21001, "e"=>23255, "w"=>"America"}]}}
  
    m
  }

  context "create job" do

    it "has audio_file url" do
      url = task.audio_file_url
    end

    it "downloads audio_file" do
      task.set_task_defaults
      audio_file.item.token = "untitled.NqMBNV.popuparchive.org"
      Utils.should_receive(:download_file).and_return(File.open(test_file('test.mp3')))

      data_file = task.download_audio_file
      data_file.should_not be_nil
      data_file.is_a?(File).should be_truthy
    end

    it "makes callback url" do
      task.set_voicebase_defaults
      task.call_back_url.should eq "http://test.popuparchive.com/voicebase_callback/files/task/#{task.extras['public_id']}"
    end

    it "processes transcript result" do
      
      trans = task.process_transcript(response)
      #STDERR.puts trans.timed_texts.pretty_inspect
      timed_text_chunks = trans.chunked_by_time(6)
      #STDERR.puts timed_text_chunks.pretty_inspect
      # transform a little to make it easier to test
      tt_chunks = {}
      timed_text_chunks.each do |ttc|
        tt_chunks[ttc['ts']] = ttc['text']
      end
      tt_chunks.should eq( {
        "00:00:00" => ["we people of the United States, in order to form a more",
                       "perfect Union, establish Justice, insure domestic tranquility,"],
        "00:00:10" => ["provide for the common defense, promote the general welfare and secure the blessings",
                       "of liberty to ourselves and our posterity, do ordain and establish this Constitution"],
        "00:00:20" => ["for the United States of America"]
      } )

    end

    it 'updates paid transcript usage' do
      now = DateTime.now
      user.collections << audio_file.item.collection
      # test user must own the collection, since usage is limited to billable ownership.
      audio_file.item.collection.set_owner(user)

      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id }
      t = Tasks::VoicebaseTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
      
      # audio_file must have the transcript, since transcripts are the billable items.
      audio_file.transcripts << t.process_transcript(response)

      t.user_id.should eq user.id.to_s
      t.extras['entity_id'].should eq user.entity.id
      t.update_premium_transcript_usage(now).should eq 60
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should eq 60

    end

    it "assigns retail cost for ondemand" do
      audio_file.item.collection.set_owner(user)
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id, 'ondemand' => true }
      t = Tasks::VoicebaseTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
      trans = t.process_transcript(response)
      trans.cost_type.should == Transcript::RETAIL
      trans.retail_cost_per_min.should == Transcriber.find_by_name('voicebase').retail_cost_per_min
      trans.cost_per_min.should == Transcriber.find_by_name('voicebase').cost_per_min
    end

    it 'delineates usage for User vs Org' do
      now = DateTime.now

      # assign user to an org
      org = FactoryGirl.create :organization
      user.organization = org
      user.save!  # because Task will do a User.find(user_id)

      # org must own the collection, since usage is limited to billable ownership.
      audio_file.item.collection.set_owner(org)

      # user must have access to the collection to act on it
      user.collections << audio_file.item.collection

      # user must own the audio_file, since usage is tied to user_id
      audio_file.set_user_id(user.id)
      audio_file.save!  # because usage calculator queries db

      # make sure we start clean
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0
      extras = { 'original' => audio_file.process_file_url, 'user_id' => user.id }
      t = Tasks::VoicebaseTranscribeTask.create!(owner: audio_file, identifier: 'test', extras: extras)
    
      # audio_file must have the transcript, since transcripts are the billable items.
      audio_file.transcripts << t.process_transcript(response)

      #STDERR.puts "task.extras = #{t.extras.inspect}"
      #STDERR.puts "audio       = #{audio_file.inspect}"
      #STDERR.puts "org         = #{org.inspect}"
      #STDERR.puts "user        = #{user.inspect}"
      #STDERR.puts "user.entity = #{user.entity.inspect}"
      t.user_id.should == user.id.to_s
      t.extras['entity_id'].should eq user.entity.id
      t.update_premium_transcript_usage(now).should == 60

      #STDERR.puts "user.monthly_usages == #{user.monthly_usages.inspect}"
      #STDERR.puts "org.monthly_usages  == #{org.monthly_usages.inspect}"

      # user has non-billable usage
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE).should == 60

      # user has zero billable usage
      user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 0

      # org has all the billable usage
      org.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS).should == 60

      # plan is org's
      audio_file.best_transcript.plan.should == org.plan

    end

    it "should measure usage" do
      task.usage_duration.should eq audio_file.duration
    end 

  end

end
