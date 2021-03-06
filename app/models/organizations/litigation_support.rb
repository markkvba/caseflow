# frozen_string_literal: true

class LitigationSupport < Organization
  def self.singleton
    LitigationSupport.first || LitigationSupport.create(name: "Litigation Support", url: "lit-support")
  end
end
