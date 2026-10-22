defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCacheTest do
  @moduledoc """
  A revoked SI's made introduction (CV-07): the usual path falls back to
  the current, repealed text (". . . ."), which names no powers; the made
  version is asked for instead.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache

  test "the repealed placeholder is told from an introduction" do
    assert EnablingCache.placeholder?(". . . . . . . . . . . . . . . .")
    assert EnablingCache.placeholder?("")
    assert EnablingCache.placeholder?(nil)

    refute EnablingCache.placeholder?(
             "The Secretary of State, in exercise of the powers conferred upon him by sections 15(1) … of the Health and Safety at Work etc. Act 1974"
           )
  end

  test "the made introduction's path" do
    assert EnablingCache.made_path("uksi", "2004", "568") ==
             "/uksi/2004/568/introduction/made/data.xml"
  end
end
