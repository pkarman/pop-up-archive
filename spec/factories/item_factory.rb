FactoryGirl.define do
  factory :item do
    association :collection, factory: :collection_public
    title "untitled"

    factory :item_private do
      association :collection, factory: :collection_private
    end

    factory :item_no_copy_media do
      association :collection, factory: :collection_no_copy_media
    end


    factory :item_with_audio do
      transient do
        audio_files_count 1
      end

      after(:create) do |item, evaluator|
        FactoryGirl.create_list(:audio_file, evaluator.audio_files_count, item: item)
      end
    end

  end

end
