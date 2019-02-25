module Core
  class Partition < ActiveRecord::Base

    has_paper_trail

    belongs_to :cluster
  end
end
