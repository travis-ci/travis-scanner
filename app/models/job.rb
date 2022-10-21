class Job < TravisRecord
  self.inheritance_column = nil

  belongs_to :repository
  belongs_to :commit
end
