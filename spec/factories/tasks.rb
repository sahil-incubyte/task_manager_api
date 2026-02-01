FactoryBot.define do
  factory :task do
    title { "Test Task" }
    description { "Task description" }
    status { "todo" }
    priority { "medium" }
    due_date { Date.today + 1 }
    association :user

    trait :todo do
      status { "todo" }
    end

    trait :in_progress do
      status { "in_progress" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :low_priority do
      priority { "low" }
    end

    trait :medium_priority do
      priority { "medium" }
    end

    trait :high_priority do
      priority { "high" }
    end
  end
end
