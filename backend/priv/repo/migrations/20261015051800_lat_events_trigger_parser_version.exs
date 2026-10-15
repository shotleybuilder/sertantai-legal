defmodule SertantaiLegal.Repo.Migrations.LatEventsTriggerParserVersion do
  @moduledoc """
  The `parsed` lat_event records `sertantai.lat.parser_version`, set by
  `LatPersister` from `ParserVersion.current/0` (lat-refactor LR-25): a law
  parsed by older parser code shows as stale. Down restores the
  20260927093413 definition.
  """
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION lat_events_on_insert() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      INSERT INTO lat_events (law_id, country, law_name, event, at, source, actor, app_version,
                              parser_version, lat_hash, struct_hash, row_count, op_key)
      SELECT r.id, r.country, r.name, 'parsed', now(),
             coalesce(lat_setting('source'), 'trigger'), lat_setting('actor'), lat_setting('app_version'),
             lat_setting('parser_version'), r.lat_hash, r.struct_hash, r.lat_count,
             coalesce(lat_setting('op_id'), txid_current()::text)
      FROM (SELECT DISTINCT law_id, country FROM lat_events_new) a
      JOIN legal_register r ON r.id = a.law_id AND r.country = a.country
      ON CONFLICT (law_id, country, event, op_key) WHERE op_key IS NOT NULL
      DO UPDATE SET lat_hash = EXCLUDED.lat_hash, struct_hash = EXCLUDED.struct_hash,
                    row_count = EXCLUDED.row_count, parser_version = EXCLUDED.parser_version;
      RETURN NULL;
    END;
    $$
    """)
  end

  def down do
    execute("""
    CREATE OR REPLACE FUNCTION lat_events_on_insert() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      INSERT INTO lat_events (law_id, country, law_name, event, at, source, actor, app_version,
                              lat_hash, struct_hash, row_count, op_key)
      SELECT r.id, r.country, r.name, 'parsed', now(),
             coalesce(lat_setting('source'), 'trigger'), lat_setting('actor'), lat_setting('app_version'),
             r.lat_hash, r.struct_hash, r.lat_count, coalesce(lat_setting('op_id'), txid_current()::text)
      FROM (SELECT DISTINCT law_id, country FROM lat_events_new) a
      JOIN legal_register r ON r.id = a.law_id AND r.country = a.country
      ON CONFLICT (law_id, country, event, op_key) WHERE op_key IS NOT NULL
      DO UPDATE SET lat_hash = EXCLUDED.lat_hash, struct_hash = EXCLUDED.struct_hash,
                    row_count = EXCLUDED.row_count;
      RETURN NULL;
    END;
    $$
    """)
  end
end
