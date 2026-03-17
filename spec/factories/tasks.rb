FactoryBot.define do
  factory :task do
    title { "Test Task" }
    description { "Task description" }
    status { "pending" }
    priority { 1 }
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
      priority { 1 }
    end

    trait :medium_priority do
      priority { 2 }
    end

    trait :high_priority do
      priority { 3 }
    end
  end
end
