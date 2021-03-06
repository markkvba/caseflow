# frozen_string_literal: true

class HearingTaskAssociation < ApplicationRecord
  belongs_to :hearing_task
  belongs_to :hearing, polymorphic: true
end
