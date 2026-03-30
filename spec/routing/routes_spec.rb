require "rails_helper"

RSpec.describe "Routes", type: :routing do
  # ========== TASK CRUD ROUTES ==========

  describe "Task CRUD routes" do
    it "routes GET /tasks to tasks#index" do
      expect(get: "/tasks").to route_to("tasks#index")
    end

    it "routes GET /tasks/:id to tasks#show" do
      expect(get: "/tasks/1").to route_to("tasks#show", id: "1")
    end

    it "routes POST /tasks to tasks#create" do
      expect(post: "/tasks").to route_to("tasks#create")
    end

    it "routes PATCH /tasks/:id to tasks#update" do
      expect(patch: "/tasks/1").to route_to("tasks#update", id: "1")
    end

    it "routes DELETE /tasks/:id to tasks#destroy" do
      expect(delete: "/tasks/1").to route_to("tasks#destroy", id: "1")
    end
  end

  # ========== COLLECTION AND MEMBER ROUTES ==========

  describe "Custom task routes" do
    it "routes GET /tasks/stats to tasks#stats" do
      expect(get: "/tasks/stats").to route_to("tasks#stats")
    end

    it "routes PATCH /tasks/:id/complete to tasks#complete" do
      expect(patch: "/tasks/1/complete").to route_to("tasks#complete", id: "1")
    end

    it "routes GET /tasks/search to tasks#search" do
      expect(get: "/tasks/search").to route_to("tasks#search")
    end
  end

  # ========== AUTHENTICATION ROUTES ==========

  describe "Authentication routes" do
    it "routes POST /signup to authentication#signup" do
      expect(post: "/signup").to route_to("authentication#signup")
    end

    it "routes POST /login to authentication#login" do
      expect(post: "/login").to route_to("authentication#login")
    end
  end

  # ========== NESTED ROUTES ==========

  describe "Nested user task routes" do
    it "routes GET /users/:user_id/tasks to user_tasks#index" do
      expect(get: "/users/1/tasks").to route_to("user_tasks#index", user_id: "1")
    end

    it "does not route POST /users/:user_id/tasks" do
      expect(post: "/users/1/tasks").not_to be_routable
    end
  end

  # ========== SINGULAR RESOURCE ==========

  describe "Profile routes (singular resource)" do
    it "routes GET /profile to profiles#show" do
      expect(get: "/profile").to route_to("profiles#show")
    end

    it "routes PATCH /profile to profiles#update" do
      expect(patch: "/profile").to route_to("profiles#update")
    end

    it "does not route GET /profiles (no index)" do
      expect(get: "/profiles").not_to be_routable
    end
  end

  # ========== API V1 NAMESPACE ==========

  describe "API v1 namespaced routes" do
    it "routes GET /api/v1/tasks to api/v1/tasks#index" do
      expect(get: "/api/v1/tasks").to route_to("api/v1/tasks#index")
    end

    it "routes GET /api/v1/tasks/:id to api/v1/tasks#show" do
      expect(get: "/api/v1/tasks/1").to route_to("api/v1/tasks#show", id: "1")
    end

    it "routes POST /api/v1/tasks to api/v1/tasks#create" do
      expect(post: "/api/v1/tasks").to route_to("api/v1/tasks#create")
    end

    it "routes PATCH /api/v1/tasks/:id to api/v1/tasks#update" do
      expect(patch: "/api/v1/tasks/1").to route_to("api/v1/tasks#update", id: "1")
    end

    it "routes DELETE /api/v1/tasks/:id to api/v1/tasks#destroy" do
      expect(delete: "/api/v1/tasks/1").to route_to("api/v1/tasks#destroy", id: "1")
    end

    it "routes GET /api/v1/tasks/stats to api/v1/tasks#stats" do
      expect(get: "/api/v1/tasks/stats").to route_to("api/v1/tasks#stats")
    end

    it "routes PATCH /api/v1/tasks/:id/complete to api/v1/tasks#complete" do
      expect(patch: "/api/v1/tasks/1/complete").to route_to("api/v1/tasks#complete", id: "1")
    end

    it "routes POST /api/v1/signup to api/v1/authentication#signup" do
      expect(post: "/api/v1/signup").to route_to("api/v1/authentication#signup")
    end

    it "routes POST /api/v1/login to api/v1/authentication#login" do
      expect(post: "/api/v1/login").to route_to("api/v1/authentication#login")
    end

    it "routes GET /api/v1/profile to api/v1/profiles#show" do
      expect(get: "/api/v1/profile").to route_to("api/v1/profiles#show")
    end

    it "routes PATCH /api/v1/profile to api/v1/profiles#update" do
      expect(patch: "/api/v1/profile").to route_to("api/v1/profiles#update")
    end
  end

  # ========== ROUTE CONSTRAINTS ==========

  describe "Route constraints" do
    it "routes GET /tasks/:id/summary with numeric ID" do
      expect(get: "/tasks/42/summary").to route_to("tasks#show", id: "42")
    end

    it "does not route GET /tasks/abc/summary with non-numeric ID" do
      expect(get: "/tasks/abc/summary").not_to be_routable
    end
  end

  # ========== SCOPED ROUTES ==========

  describe "Admin scoped routes" do
    it "routes GET /admin/stats to tasks#stats" do
      expect(get: "/admin/stats").to route_to("tasks#stats")
    end
  end
end
