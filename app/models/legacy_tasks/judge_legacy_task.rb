class JudgeLegacyTask < LegacyTask
  def self.from_vacols(record, appeal, user_id)
    task = super
    task.action = record.reassigned_to_judge_date.present? ? "review" : "assign"
    if task.action == "review"
      # If task action is 'assign' that means there was no previous task record yet
      task.previous_task = LegacyTask.new(assigned_at: record.assigned_to_attorney_date.try(:to_date))
    end
    task.work_product = record.work_product
    task
  end
end
