defmodule SertantaiLegal.Scraper.DefinitionParser.XmlUtilsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.DefinitionParser.XmlUtils

  defp parse_xml(xml) do
    {parsed, _} = xml |> String.to_charlist() |> :xmerl_scan.string(namespace_conformant: true)
    parsed
  end

  # ── text_content/1 ────────────────────────────────────────────

  describe "text_content/1" do
    test "extracts plain text from simple element" do
      xml = ~s(<Root xmlns="http://example.com"><Text>hello world</Text></Root>)
      parsed = parse_xml(xml)
      assert XmlUtils.text_content(parsed) =~ "hello world"
    end

    test "preserves child element text order (Acronym inside Term)" do
      xml =
        ~s(<Root xmlns="http://example.com"><Term><Acronym>CEN</Acronym>/TS 15359</Term></Root>)

      parsed = parse_xml(xml)
      assert String.trim(XmlUtils.text_content(parsed)) == "CEN/TS 15359"
    end

    test "inserts newline before ListItem elements" do
      xml = """
      <Root xmlns="http://example.com">
        <OrderedList>
          <ListItem><Para><Text>first item</Text></Para></ListItem>
          <ListItem><Para><Text>second item</Text></Para></ListItem>
        </OrderedList>
      </Root>
      """

      parsed = parse_xml(xml)
      text = XmlUtils.text_content(parsed)

      assert String.contains?(text, "\n"),
             "Expected newline between ListItems, got: #{inspect(text)}"

      lines = text |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      assert "first item" in lines
      assert "second item" in lines
    end

    test "inserts newline before P3 elements" do
      xml = """
      <Root xmlns="http://example.com">
        <P2para>
          <Text>preamble</Text>
          <P3><P3para><Text>sub-item a</Text></P3para></P3>
          <P3><P3para><Text>sub-item b</Text></P3para></P3>
        </P2para>
      </Root>
      """

      parsed = parse_xml(xml)
      text = XmlUtils.text_content(parsed)
      lines = text |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

      assert length(lines) >= 3, "Expected preamble + 2 sub-items on separate lines"
      assert "preamble" in lines
      assert "sub-item a" in lines
      assert "sub-item b" in lines
    end
  end

  # ── text_content_for_definition/1 ──────────────────────────────

  describe "text_content_for_definition/1" do
    test "skips nested UnorderedList with Class=Definition" do
      xml = """
      <Root xmlns="http://example.com">
        <ListItem>
          <Para><Text>parent text</Text></Para>
          <UnorderedList Class="Definition">
            <ListItem><Para><Text>nested def text</Text></Para></ListItem>
          </UnorderedList>
        </ListItem>
      </Root>
      """

      import SweetXml
      parsed = parse_xml(xml)
      [item] = xpath(parsed, ~x"//ListItem"l) |> Enum.take(1)
      text = XmlUtils.text_content_for_definition(item)

      assert String.contains?(text, "parent text")

      refute String.contains?(text, "nested def text"),
             "Should exclude nested Definition list, got: #{inspect(text)}"
    end

    test "preserves OrderedList sub-items with newlines" do
      xml = """
      <Root xmlns="http://example.com">
        <ListItem>
          <Para>
            <Text>term means -</Text>
            <OrderedList>
              <ListItem><Para><Text>first option; or</Text></Para></ListItem>
              <ListItem><Para><Text>second option.</Text></Para></ListItem>
            </OrderedList>
          </Para>
        </ListItem>
      </Root>
      """

      import SweetXml
      parsed = parse_xml(xml)
      [item] = xpath(parsed, ~x"//ListItem"l) |> Enum.take(1)
      text = XmlUtils.text_content_for_definition(item)

      assert String.contains?(text, "\n"),
             "Expected newlines between OrderedList items"

      assert String.contains?(text, "first option")
      assert String.contains?(text, "second option")
    end

    test "does not skip plain UnorderedList (no Class=Definition)" do
      xml = """
      <Root xmlns="http://example.com">
        <ListItem>
          <Para><Text>parent</Text></Para>
          <UnorderedList Decoration="none">
            <ListItem><Para><Text>sub-item</Text></Para></ListItem>
          </UnorderedList>
        </ListItem>
      </Root>
      """

      import SweetXml
      parsed = parse_xml(xml)
      [item] = xpath(parsed, ~x"//ListItem"l) |> Enum.take(1)
      text = XmlUtils.text_content_for_definition(item)

      assert String.contains?(text, "parent")
      assert String.contains?(text, "sub-item")
    end
  end
end
