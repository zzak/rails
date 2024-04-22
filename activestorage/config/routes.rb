# frozen_string_literal: true

require "active_storage/engine/routes"

Rails.application.routes.draw do
  ActiveStorage::Routes.draw_routes!
end if ActiveStorage.draw_routes
