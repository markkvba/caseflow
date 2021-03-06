# frozen_string_literal: true

describe Docket do
  before do
    FeatureToggle.enable!(:ama_auto_case_distribution)
    FeatureToggle.enable!(:ama_acd_tasks)
  end
  after do
    FeatureToggle.disable!(:ama_auto_case_distribution)
    FeatureToggle.disable!(:ama_acd_tasks)
  end

  context "docket" do
    # nonpriority
    let!(:appeal) { create(:appeal, :with_tasks, docket_type: "direct_review") }
    let!(:denied_aod_motion_appeal) do
      create(:appeal, :denied_advance_on_docket, :with_tasks, docket_type: "direct_review")
    end
    let!(:inapplicable_aod_motion_appeal) do
      create(:appeal, :inapplicable_aod_motion, :with_tasks, docket_type: "direct_review")
    end

    # priority
    let!(:aod_age_appeal) { create(:appeal, :advanced_on_docket_due_to_age, :with_tasks, docket_type: "direct_review") }
    let!(:aod_motion_appeal) do
      create(:appeal, :advanced_on_docket_due_to_motion, :with_tasks, docket_type: "direct_review")
    end

    context "appeals" do
      context "when no options given" do
        subject { DirectReviewDocket.new.appeals }
        it "returns all appeals if no option given" do
          expect(subject).to include appeal
          expect(subject).to include denied_aod_motion_appeal
          expect(subject).to include inapplicable_aod_motion_appeal
          expect(subject).to include aod_age_appeal
          expect(subject).to include aod_motion_appeal
        end
      end

      context "when looking for only priority and ready appeals" do
        subject { DirectReviewDocket.new.appeals(priority: true, ready: true) }
        it "returns priority/ready appeals" do
          expect(subject).to_not include appeal
          expect(subject).to_not include denied_aod_motion_appeal
          expect(subject).to_not include inapplicable_aod_motion_appeal
          expect(subject).to include aod_age_appeal
          expect(subject).to include aod_motion_appeal
        end
      end

      context "when looking for only nonpriority appeals" do
        subject { DirectReviewDocket.new.appeals(priority: false) }
        it "returns nonpriority appeals" do
          expect(subject).to include appeal
          expect(subject).to include denied_aod_motion_appeal
          expect(subject).to include inapplicable_aod_motion_appeal
          expect(subject).to_not include aod_age_appeal
          expect(subject).to_not include aod_motion_appeal
        end
      end
    end

    context "count" do
      let(:priority) { nil }
      subject { DirectReviewDocket.new.count(priority: priority) }

      it "counts appeals" do
        expect(subject).to eq(5)
      end

      context "when looking for nonpriority appeals" do
        let(:priority) { false }
        it "counts nonpriority appeals" do
          expect(subject).to eq(3)
        end
      end
    end

    context "age_of_n_oldest_priority_appeals" do
      subject { DirectReviewDocket.new.age_of_n_oldest_priority_appeals(1) }

      it "returns the 'ready at' field of the oldest priority appeals that are ready for distribution" do
        expect(subject.length).to eq(1)
        expect(subject.first).to eq(aod_age_appeal.ready_for_distribution_at)
      end
    end

    context "distribute_appeals" do
      context "priority appeals" do
        subject { DirectReviewDocket.new.distribute_appeals(distribution, priority: true, limit: 2) }

        let(:judge_user) { create(:user) }
        let!(:vacols_judge) { create(:staff, :judge_role, sdomainid: judge_user.css_id) }
        let!(:distribution) { Distribution.create!(judge: judge_user) }

        it "distributes and appeals" do
          tasks = subject

          expect(tasks.length).to eq(2)
          expect(tasks.first.class).to eq(DistributedCase)
          expect(distribution.distributed_cases.length).to eq(2)
          expect(judge_user.reload.tasks.map(&:appeal)).to include(aod_age_appeal)
        end
      end
    end
  end

  context "distribute_appeals" do
    let!(:appeals) do
      (1..10).map do
        create(:appeal, :with_tasks, docket_type: "direct_review")
      end
    end

    let(:judge_user) { create(:user) }
    let!(:vacols_judge) { create(:staff, :judge_role, sdomainid: judge_user.css_id) }
    let!(:distribution) { Distribution.create!(judge: judge_user) }

    context "nonpriority appeals" do
      subject { DirectReviewDocket.new.distribute_appeals(distribution, priority: false, limit: 10) }

      it "creates distributed cases and judge tasks" do
        tasks = subject

        expect(tasks.length).to eq(10)
        expect(tasks.first.class).to eq(DistributedCase)
        expect(distribution.distributed_cases.length).to eq(10)
        expect(judge_user.reload.tasks.map(&:appeal)).to include(appeals.first)
      end
    end
  end
end
