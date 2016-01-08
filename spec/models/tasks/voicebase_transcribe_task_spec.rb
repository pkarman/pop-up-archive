require 'spec_helper'

describe Tasks::VoicebaseTranscribeTask do

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:user) { FactoryGirl.create :user }
  let(:audio_file) { FactoryGirl.create :audio_file_private, user_id: user.id }
  let(:task) { Tasks::VoicebaseTranscribeTask.new(owner: audio_file, extras: {'user_id' => user.id}) }

let(:response) {
    m = Hashie::Mash.new
    m.body = {
 "name"=>"latest",
 "revision"=>"dfbb21ac-ac93-426a-b14a-d9005e7f66d7",
 "type"=>"machine",
 "engine"=>"standard",
 "formats"=>["json", "text", "srt"],
 "transcript"=>
    {"name"=>"latest",
     "revision"=>"ca72a4a9-3d00-4e1d-a429-1495fe69818f",
     "words"=>
      [{"w"=>"I'll", "e"=>15600, "s"=>5040, "c"=>0.539, "p"=>0},
       {"w"=>".", "e"=>16190, "s"=>15600, "c"=>0.0, "p"=>1, "m"=>"punc"},
       {"w"=>"Apparently", "e"=>16940, "s"=>16190, "c"=>0.501, "p"=>2},
       {"w"=>"C.N.N.", "e"=>17170, "s"=>16940, "c"=>0.501, "p"=>3},
       {"w"=>"has", "e"=>17570, "s"=>17170, "c"=>0.816, "p"=>4},
       {"w"=>"picked", "e"=>17770, "s"=>17570, "c"=>0.518, "p"=>5},
       {"w"=>"out", "e"=>17850, "s"=>17770, "c"=>0.805, "p"=>6},
       {"w"=>"a", "e"=>18330, "s"=>17850, "c"=>0.741, "p"=>7},
       {"w"=>"song", "e"=>18789, "s"=>18330, "c"=>0.544, "p"=>8},
       {"w"=>"from", "e"=>18950, "s"=>18790, "c"=>0.806, "p"=>9},
       {"w"=>"the", "e"=>19170, "s"=>18950, "c"=>0.718, "p"=>10},
       {"w"=>"end", "e"=>19230, "s"=>19170, "c"=>0.516, "p"=>11},
       {"w"=>"of", "e"=>19340, "s"=>19230, "c"=>0.594, "p"=>12},
       {"w"=>"the", "e"=>19730, "s"=>19340, "c"=>0.65, "p"=>13},
       {"w"=>"world", "e"=>20150, "s"=>19730, "c"=>0.84, "p"=>14},
       {"w"=>".", "e"=>20520, "s"=>20150, "c"=>0.0, "p"=>15, "m"=>"punc"},
       {"w"=>"In", "e"=>20640, "s"=>20520, "c"=>0.791, "p"=>16},
       {"w"=>"the", "e"=>20980, "s"=>20640, "c"=>0.759, "p"=>17},
       {"w"=>"eighty's", "e"=>21050, "s"=>20980, "c"=>0.519, "p"=>18},
       {"w"=>"during", "e"=>21380, "s"=>21050, "c"=>0.551, "p"=>19},
       {"w"=>"the", "e"=>21699, "s"=>21380, "c"=>0.674, "p"=>20},
       {"w"=>"Cold", "e"=>21870, "s"=>21700, "c"=>0.708, "p"=>21},
       {"w"=>"War", "e"=>22210, "s"=>21870, "c"=>0.683, "p"=>22},
       {"w"=>".", "e"=>22679, "s"=>22210, "c"=>0.0, "p"=>23, "m"=>"punc"},
       {"w"=>"C.N.N.", "e"=>22870, "s"=>22680, "c"=>0.505, "p"=>24},
       {"w"=>"made", "e"=>22920, "s"=>22870, "c"=>0.628, "p"=>25},
       {"w"=>"a", "e"=>23590, "s"=>22920, "c"=>0.745, "p"=>26},
       {"w"=>"videotape", "e"=>23700, "s"=>23590, "c"=>0.523, "p"=>27},
       {"w"=>"of", "e"=>23920, "s"=>23700, "c"=>0.697, "p"=>28},
       {"w"=>"a", "e"=>24180, "s"=>23920, "c"=>0.776, "p"=>29},
       {"w"=>"marching", "e"=>24320, "s"=>24180, "c"=>0.503, "p"=>30},
       {"w"=>"band", "e"=>24930, "s"=>24320, "c"=>0.656, "p"=>31},
       {"w"=>"playing", "e"=>25150, "s"=>24930, "c"=>0.852, "p"=>32},
       {"w"=>"this", "e"=>25600, "s"=>25150, "c"=>0.586, "p"=>33},
       {"w"=>"tune", "e"=>26420, "s"=>25600, "c"=>0.541, "p"=>34},
       {"w"=>".", "e"=>26650, "s"=>26420, "c"=>0.0, "p"=>35, "m"=>"punc"},
       {"w"=>"There's", "e"=>26680, "s"=>26650, "c"=>0.504, "p"=>36},
       {"w"=>"a", "e"=>26840, "s"=>26680, "c"=>0.671, "p"=>37},
       {"w"=>"note", "e"=>26970, "s"=>26840, "c"=>0.538, "p"=>38},
       {"w"=>"on", "e"=>27010, "s"=>26970, "c"=>0.792, "p"=>39},
       {"w"=>"the", "e"=>27280, "s"=>27010, "c"=>0.72, "p"=>40},
       {"w"=>"take", "e"=>27650, "s"=>27280, "c"=>0.502, "p"=>41},
       {"w"=>"that", "e"=>27850, "s"=>27650, "c"=>0.787, "p"=>42},
       {"w"=>"says", "e"=>28000, "s"=>27850, "c"=>0.83, "p"=>43},
       {"w"=>"that", "e"=>28090, "s"=>28000, "c"=>0.785, "p"=>44},
       {"w"=>"it", "e"=>28280, "s"=>28090, "c"=>0.795, "p"=>45},
       {"w"=>"should", "e"=>28370, "s"=>28280, "c"=>0.738, "p"=>46},
       {"w"=>"be", "e"=>28760, "s"=>28370, "c"=>0.673, "p"=>47},
       {"w"=>"played", "e"=>28900, "s"=>28760, "c"=>0.604, "p"=>48},
       {"w"=>".", "e"=>29210, "s"=>28900, "c"=>0.0, "p"=>49, "m"=>"punc"},
       {"w"=>"Only", "e"=>29390, "s"=>29210, "c"=>0.596, "p"=>50},
       {"w"=>"once", "e"=>29529, "s"=>29390, "c"=>0.851, "p"=>51},
       {"w"=>"the", "e"=>29840, "s"=>29530, "c"=>0.769, "p"=>52},
       {"w"=>"end", "e"=>29920, "s"=>29840, "c"=>0.527, "p"=>53},
       {"w"=>"of", "e"=>30080, "s"=>29920, "c"=>0.582, "p"=>54},
       {"w"=>"the", "e"=>30430, "s"=>30080, "c"=>0.692, "p"=>55},
       {"w"=>"world", "e"=>30590, "s"=>30430, "c"=>0.814, "p"=>56},
       {"w"=>"has", "e"=>30820, "s"=>30590, "c"=>0.82, "p"=>57},
       {"w"=>"been", "e"=>31140, "s"=>30820, "c"=>0.766, "p"=>58},
       {"w"=>"confirmed", "e"=>31670, "s"=>31140, "c"=>0.528, "p"=>59},
       {"w"=>".", "e"=>32200, "s"=>31670, "c"=>0.0, "p"=>60, "m"=>"punc"},
       {"w"=>"If", "e"=>32500, "s"=>32200, "c"=>0.535, "p"=>61},
       {"w"=>"that", "e"=>32619, "s"=>32500, "c"=>0.789, "p"=>62},
       {"w"=>"really", "e"=>33250, "s"=>32619, "c"=>0.55, "p"=>63},
       {"w"=>"happens", "e"=>33570, "s"=>33250, "c"=>0.831, "p"=>64},
       {"w"=>".", "e"=>33790, "s"=>33570, "c"=>0.0, "p"=>65, "m"=>"punc"},
       {"w"=>"This", "e"=>33950, "s"=>33790, "c"=>0.563, "p"=>66},
       {"w"=>"song", "e"=>34180, "s"=>33950, "c"=>0.511, "p"=>67},
       {"w"=>".", "e"=>34540, "s"=>34180, "c"=>0.0, "p"=>68, "m"=>"punc"},
       {"w"=>"Could", "e"=>34640, "s"=>34540, "c"=>0.84, "p"=>69},
       {"w"=>"be", "e"=>34750, "s"=>34640, "c"=>0.716, "p"=>70},
       {"w"=>"the", "e"=>35050, "s"=>34750, "c"=>0.769, "p"=>71},
       {"w"=>"last", "e"=>35360, "s"=>35050, "c"=>0.822, "p"=>72},
       {"w"=>"things", "e"=>35840, "s"=>35360, "c"=>0.507, "p"=>73},
       {"w"=>"ever", "e"=>36000, "s"=>35840, "c"=>0.548, "p"=>74},
       {"w"=>"hit", "e"=>56400, "s"=>36000, "c"=>0.52, "p"=>75},
       {"w"=>"us", "e"=>57770, "s"=>56400, "c"=>0.683, "p"=>76},
       {"w"=>"the", "e"=>58750, "s"=>57770, "c"=>0.722, "p"=>77},
       {"w"=>"most", "e"=>63060, "s"=>58750, "c"=>0.834, "p"=>78},
       {"w"=>"amount", "e"=>72240, "s"=>63060, "c"=>0.506, "p"=>79},
       {"w"=>".", "e"=>72390, "s"=>72240, "c"=>0.0, "p"=>80, "m"=>"punc"},
       {"w"=>"The", "e"=>72690, "s"=>72390, "c"=>0.589, "p"=>81},
       {"w"=>"World", "e"=>72780, "s"=>72690, "c"=>0.823, "p"=>82},
       {"w"=>"According", "e"=>73110, "s"=>72780, "c"=>0.526, "p"=>83},
       {"w"=>"To", "e"=>73570, "s"=>73110, "c"=>0.614, "p"=>84},
       {"w"=>"sound", "e"=>73680, "s"=>73570, "c"=>0.504, "p"=>85},
       {"w"=>"is", "e"=>73890, "s"=>73680, "c"=>0.794, "p"=>86},
       {"w"=>"made", "e"=>73960, "s"=>73890, "c"=>0.598, "p"=>87},
       {"w"=>"by", "e"=>74280, "s"=>73960, "c"=>0.78, "p"=>88},
       {"w"=>"Chris", "e"=>74540, "s"=>74280, "c"=>0.508, "p"=>89},
       {"w"=>"off", "e"=>74900, "s"=>74540, "c"=>0.501, "p"=>90},
       {"w"=>"in", "e"=>75080, "s"=>74900, "c"=>0.688, "p"=>91},
       {"w"=>"to", "e"=>75430, "s"=>75080, "c"=>0.518, "p"=>92},
       {"w"=>"harness", "e"=>77260, "s"=>75430, "c"=>0.501, "p"=>93},
       {"w"=>"the", "e"=>81680, "s"=>77260, "c"=>0.742, "p"=>94},
       {"w"=>"power", "e"=>85670, "s"=>81680, "c"=>0.841, "p"=>95},
       {"w"=>".",
        "e"=>85670,
        "s"=>85670,
        "c"=>0.0,
        "p"=>96,
        "m"=>"punc"}],
      "diarization"=>
        [{"speakerLabel"=>"S0", "band"=>"S", "start"=>1950, "length"=>5130, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>7080, "length"=>8550, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S11", "band"=>"S", "start"=>15630, "length"=>10710, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S11", "band"=>"S", "start"=>26340, "length"=>9830, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>36170, "length"=>5830, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>42000, "length"=>13800, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>55800, "length"=>11280, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>67080, "length"=>5170, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S11", "band"=>"S", "start"=>72250, "length"=>3720, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>75970, "length"=>6030, "gender"=>"M", "env"=>"U"},
         {"speakerLabel"=>"S0", "band"=>"S", "start"=>82000, "length"=>2090, "gender"=>"M", "env"=>"U"}]
        }
      }
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
        "00:00:05" => ["I'll."],
        "00:00:16" => ["Apparently C.N.N. has picked out a song from the end of the world. In the eighty's during", "the Cold War. C.N.N. made a videotape of a marching band playing this tune."],
        "00:00:26" => ["There's a note on the take that says that it should be played. Only once the end of the world has been confirmed.", "If that really happens. This song. Could be the last things ever hit"],
        "00:00:56" => ["us the most"],
        "00:01:03" => ["amount."],
        "00:01:12" => ["The World According To sound is made by Chris off in to harness the"],
        "00:01:21" => ["power."]
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
