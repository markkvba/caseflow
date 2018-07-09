describe SupplementalClaimIntake do
  before do
    FeatureToggle.enable!(:test_facols)
    Timecop.freeze(Time.utc(2019, 1, 1, 12, 0, 0))
  end

  after do
    FeatureToggle.disable!(:test_facols)
  end

  let(:veteran_file_number) { "64205555" }
  let(:user) { Generators::User.build }
  let(:detail) { nil }
  let!(:veteran) { Generators::Veteran.build(file_number: "64205555") }
  let(:completed_at) { nil }

  let(:intake) do
    SupplementalClaimIntake.new(
      user: user,
      detail: detail,
      veteran_file_number: veteran_file_number,
      completed_at: completed_at
    )
  end

  context "#start!" do
    subject { intake.start! }

    context "intake is already in progress" do
      it "should not create another intake" do
        SupplementalClaimIntake.new(
          user: user,
          veteran_file_number: veteran_file_number
        ).start!

        expect(intake).to_not be_nil
        expect(subject).to eq(false)
      end
    end
  end

  context "#cancel!" do
    subject { intake.cancel!(reason: "system_error", other: nil) }

    let(:detail) do
      SupplementalClaim.create!(
        veteran_file_number: "64205555",
        receipt_date: 3.days.ago
      )
    end

    let!(:claimant) do
      Claimant.create!(
        review_request: detail,
        participant_id: "1234"
      )
    end

    it "cancels and deletes the supplemental claim record created" do
      subject

      expect(intake.reload).to be_canceled
      expect { detail.reload }.to raise_error ActiveRecord::RecordNotFound
      expect(intake).to have_attributes(
        cancel_reason: "system_error",
        cancel_other: nil
      )
      expect { claimant.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context "#review!" do
    subject { intake.review!(params) }

    let(:detail) do
      SupplementalClaim.create!(
        veteran_file_number: "64205555",
        receipt_date: 3.days.ago
      )
    end

    context "Veteran is claimant" do
      let(:params) do
        ActionController::Parameters.new(
          receipt_date: 1.day.ago,
          claimant: nil
        )
      end

      it "adds veteran to claimants" do
        subject

        expect(intake.detail.claimants.count).to eq 1
        expect(intake.detail.claimants.first).to have_attributes(
          participant_id: intake.veteran.participant_id
        )
      end
    end

    context "Claimant is different than Veteran" do
      let(:params) do
        ActionController::Parameters.new(
          receipt_date: 1.day.ago,
          claimant: "1234"
        )
      end

      it "adds other relationship to claimants" do
        subject

        expect(intake.detail.claimants.count).to eq 1
        expect(intake.detail.claimants.first).to have_attributes(
          participant_id: "1234"
        )
      end
    end
  end

  context "#complete!" do
    subject { intake.complete!(params) }

    let(:params) do
      { request_issues: [
        { profile_date: "2018-04-30", reference_id: "reference-id", decision_text: "decision text" }
      ] }
    end

    let(:detail) do
      SupplementalClaim.create!(
        veteran_file_number: "64205555",
        receipt_date: 3.days.ago
      )
    end

    it "completes the intake and creates an end product" do
      expect(Fakes::VBMSService).to receive(:establish_claim!).and_call_original
      allow(Fakes::VBMSService).to receive(:create_contentions!).and_call_original

      subject

      expect(intake.reload).to be_success
      expect(intake.detail.established_at).to_not be_nil
      expect(intake.detail.end_product_reference_id).to_not be_nil
      expect(intake.detail.request_issues.count).to eq 1
      expect(intake.detail.request_issues.first).to have_attributes(
        rating_issue_reference_id: "reference-id",
        rating_issue_profile_date: Date.new(2018, 4, 30),
        description: "decision text"
      )
      expect(Fakes::VBMSService).to have_received(:create_contentions!).with(
        veteran_file_number: intake.detail.veteran_file_number,
        claim_id: intake.detail.end_product_reference_id,
        contention_descriptions: ["decision text"]
      )
    end

    it "creates end products with incrementing end product modifiers" do
      allow(Fakes::VBMSService).to receive(:establish_claim!).and_call_original
      allow(Fakes::VBMSService).to receive(:create_contentions!).and_call_original

      Generators::EndProduct.build(
        veteran_file_number: "64205555",
        bgs_attrs: { end_product_type_code: "040" }
      )

      subject

      expect(Fakes::VBMSService).to have_received(:establish_claim!).with(
        claim_hash: {
          benefit_type_code: "1",
          payee_code: "00",
          predischarge: false,
          claim_type: "Claim",
          station_of_jurisdiction: "397",
          date: detail.receipt_date.to_date,
          end_product_modifier: "041",
          end_product_label: "Supplemental Claim Rating",
          end_product_code: "040SCR",
          gulf_war_registry: false,
          suppress_acknowledgement_letter: false
        },
        veteran_hash: intake.veteran.to_vbms_hash
      )
    end

    context "when no requested issues" do
      let(:params) do
        { request_issues: [] }
      end
      it "returns nil" do
        expect(Fakes::VBMSService).not_to receive(:establish_claim!)
        expect(Fakes::VBMSService).not_to receive(:create_contentions!)
      end
    end

    context "if end product creation fails" do
      let(:unknown_error) do
        Caseflow::Error::EstablishClaimFailedInVBMS.new("error")
      end

      it "clears pending status" do
        allow_any_instance_of(SupplementalClaim).to receive(
          :create_end_product_and_contentions!
        ).and_raise(unknown_error)

        expect { subject }.to raise_exception
        expect(intake.completion_status).to be_nil
      end
    end
  end
end
