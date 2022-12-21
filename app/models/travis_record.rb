class TravisRecord < ApplicationRecord
  self.abstract_class = true

  establish_connection("travis_#{Rails.env}".to_sym)
end
