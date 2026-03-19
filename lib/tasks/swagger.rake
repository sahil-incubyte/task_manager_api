namespace :swagger do
  desc "Regenerate Swagger docs and check for drift"
  task verify: :environment do
    pattern = "spec/requests/**/*_spec.rb, spec/api/**/*_spec.rb, spec/integration/**/*_spec.rb, spec/swagger/**/*_spec.rb"
    system({ "PATTERN" => pattern }, "bundle exec rails rswag:specs:swaggerize")
    if system("git diff --quiet swagger/")
      puts "Swagger docs are up-to-date."
    else
      abort "Swagger docs are stale! Run `rails rswag:specs:swaggerize` and commit."
    end
  end
end
