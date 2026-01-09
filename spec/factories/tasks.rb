FactoryBot.define do
  factory :task do
    title { "Test Task" }
    description { "Task description" }
    status { "pending" }
    priority { 1 }
    due_date { Date.today + 1 }
    association :user
  end
end
