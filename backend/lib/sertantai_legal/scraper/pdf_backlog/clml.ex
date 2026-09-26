defmodule SertantaiLegal.Scraper.PdfBacklog.Clml do
  @moduledoc """
  Pure conversion of a parsed PDF-backlog `Transcript` into legislation.gov.uk
  CLML (the `/body/data.xml` shape), so `LatParser` — and the rest of the LAT
  pipeline — handles PDF-sourced laws exactly as XML-sourced ones: same
  section ids, sort keys, depths and persistence.

  Emits only the subset `LatParser` reads: `Body` (P1group/P1/P2/P3, Pblock
  headings, SignedSection) and `Schedules`, with the transcript's `extent`
  as the root `RestrictExtent`.
  """

  alias SertantaiLegal.Scraper.PdfBacklog.Transcript

  @primary_types ~w(ukpga asp anaw asc nia mwa ukla apgb aep aosp aip apni mnia)

  @doc "Render a transcript as CLML body XML."
  @spec to_clml(Transcript.t()) :: String.t()
  def to_clml(%Transcript{} = t) do
    kind = if type_code(t.meta["law_name"]) in @primary_types, do: "Primary", else: "Secondary"
    extent = if t.meta["extent"], do: ~s( RestrictExtent="#{esc(t.meta["extent"])}"), else: ""

    IO.iodata_to_binary([
      "<Legislation#{extent}><#{kind}><Body>",
      Enum.map(t.body, &item/1),
      signed(t.signed),
      "</Body>",
      schedules(t.schedules),
      "</#{kind}></Legislation>"
    ])
  end

  defp type_code("UK_" <> rest), do: rest |> String.split("_") |> hd()
  defp type_code(_), do: nil

  defp item(%{type: :heading, title: title}),
    do: ["<Pblock><Title>", esc(title), "</Title></Pblock>"]

  defp item(%{type: :p1} = p1) do
    title = if p1.heading, do: ["<Title>", esc(p1.heading), "</Title>"], else: []

    [
      "<P1group>",
      title,
      "<P1>",
      pnumber(p1.num),
      "<P1para>",
      body(p1),
      "</P1para></P1></P1group>"
    ]
  end

  defp item(%{type: :p2} = p2),
    do: ["<P2>", pnumber(p2.num), "<P2para>", body(p2), "</P2para></P2>"]

  defp item(%{type: :p3} = p3),
    do: ["<P3>", pnumber(p3.num), "<P3para>", Enum.map(p3.text, &text/1), "</P3para></P3>"]

  defp body(node) do
    [
      Enum.map(node.text, &text/1),
      Enum.map(node.children, &item/1),
      Enum.map(node.trailing, &text/1)
    ]
  end

  defp signed([]), do: []

  defp signed(lines),
    do: [
      "<SignedSection><Signatory>",
      Enum.map(lines, &["<Para>", text(&1), "</Para>"]),
      "</Signatory></SignedSection>"
    ]

  defp schedules([]), do: []

  defp schedules(schs) do
    [
      "<Schedules>",
      Enum.map(schs, fn s ->
        title =
          if s.title, do: ["<TitleBlock><Title>", esc(s.title), "</Title></TitleBlock>"], else: []

        [
          "<Schedule><Number>SCHEDULE ",
          esc(s.number),
          "</Number>",
          title,
          "<ScheduleBody>",
          Enum.map(s.items, &item/1),
          "</ScheduleBody></Schedule>"
        ]
      end),
      "</Schedules>"
    ]
  end

  defp pnumber(n), do: ["<Pnumber>", esc(n), "</Pnumber>"]
  defp text(t), do: ["<Text>", esc(t), "</Text>"]

  defp esc(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
