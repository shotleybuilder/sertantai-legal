defmodule SertantaiLegal.Sync.ChangeNotifierTest do
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.ChangeNotifier

  @test_org_id "00000000-aaaa-bbbb-cccc-111111111111"

  setup do
    {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

    # Clean up
    Repo.query!("DELETE FROM applicability_events WHERE organization_id = $1", [org_id_binary])

    # Seed change detection events
    Repo.query!(
      """
      INSERT INTO applicability_events
        (id, organization_id, law_name, event, actor, status_before, status_after,
         source, materiality, review_due_date, metadata, inserted_at)
      VALUES
        (gen_random_uuid(), $1, 'UK_uksi_2024_N01', 'law_status_changed', 'sertantai',
         'yes', 'yes', 'change_detection', 'major', $2,
         '{"change_type": "repealed", "title": "Repealed Law"}', NOW()),
        (gen_random_uuid(), $1, 'UK_uksi_2024_N02', 'law_status_changed', 'sertantai',
         'yes', 'yes', 'change_detection', 'major', $2,
         '{"change_type": "repealed", "title": "Another Repealed"}', NOW()),
        (gen_random_uuid(), $1, 'UK_uksi_2024_N03', 'new_law_available', 'sertantai',
         NULL, 'unreviewed', 'change_detection', 'major', $2,
         '{"title": "New Safety Regs", "match_score": 2}', NOW()),
        (gen_random_uuid(), $1, 'UK_uksi_2024_N04', 'match_score_changed', 'sertantai',
         'yes', 'yes', 'enrichment', 'moderate', $3,
         '{"change_type": "enrichment_update"}', NOW())
      """,
      [org_id_binary, Date.add(Date.utc_today(), 30), Date.add(Date.utc_today(), 60)]
    )

    on_exit(fn ->
      Repo.query!("DELETE FROM applicability_events WHERE organization_id = $1", [org_id_binary])
    end)

    %{org_id: @test_org_id, org_id_binary: org_id_binary}
  end

  describe "generate_summaries/0" do
    test "returns summary for orgs with pending changes" do
      {:ok, summaries} = ChangeNotifier.generate_summaries()

      # Our test org should be in the results
      summary =
        Enum.find(summaries, fn s ->
          case Ecto.UUID.load(s.organization_id) do
            {:ok, id} -> id == @test_org_id
            _ -> false
          end
        end)

      assert summary != nil
      assert summary.counts.total == 4
      assert summary.counts.major == 3
      assert summary.counts.moderate == 1
      assert summary.by_event.law_status_changed == 2
      assert summary.by_event.new_law_available == 1
      assert summary.by_event.match_score_changed == 1
    end
  end

  describe "generate_summary/1" do
    test "returns summary for a specific org", %{org_id: org_id} do
      {:ok, summary} = ChangeNotifier.generate_summary(org_id)

      assert summary.counts.total == 4
      assert summary.counts.major == 3
    end
  end

  describe "build_email_body/1" do
    test "includes materiality counts and breakdown", %{org_id: org_id} do
      {:ok, summary} = ChangeNotifier.generate_summary(org_id)
      body = ChangeNotifier.build_email_body(summary)

      assert body =~ "3 major changes"
      assert body =~ "1 moderate change"
      assert body =~ "2 laws repealed"
      assert body =~ "1 new law matching"
      assert body =~ "1 law with enrichment"
      assert body =~ "Review your changes"
    end

    test "includes overdue warning when applicable", %{org_id_binary: org_id_binary} do
      # Add an overdue event
      Repo.query!(
        """
        INSERT INTO applicability_events
          (id, organization_id, law_name, event, actor, status_before, status_after,
           source, materiality, review_due_date, metadata, inserted_at)
        VALUES
          (gen_random_uuid(), $1, 'UK_uksi_2024_N05', 'law_status_changed', 'sertantai',
           'yes', 'yes', 'change_detection', 'major', $2,
           '{"change_type": "repealed"}', NOW())
        """,
        [org_id_binary, Date.add(Date.utc_today(), -10)]
      )

      {:ok, summary} = ChangeNotifier.generate_summary(@test_org_id)
      body = ChangeNotifier.build_email_body(summary)

      assert body =~ "WARNING"
      assert body =~ "overdue"
    end
  end

  describe "change_subject/1" do
    test "includes major count and new matches", %{org_id: org_id} do
      {:ok, summary} = ChangeNotifier.generate_summary(org_id)
      subject = ChangeNotifier.change_subject(summary)

      assert subject =~ "3 major"
      assert subject =~ "1 new matches"
      assert subject =~ "4 total"
    end
  end

  describe "notify_all/0" do
    test "returns count of notified orgs" do
      {:ok, count} = ChangeNotifier.notify_all()
      assert count >= 1
    end
  end
end
