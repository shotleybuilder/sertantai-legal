defmodule SertantaiLegal.Legal.AmendmentAnnotation.CodeType do
  @moduledoc """
  Annotation code type enum for amendment_annotations rows.

  Maps to legislation.gov.uk footnote prefixes:
  - F-codes → :amendment (textual amendments)
  - C-codes → :modification (modifications to how provisions apply)
  - I-codes → :commencement (bringing into force)
  - E-codes → :extent_editorial (extent/territorial + editorial notes)
  """

  use Ash.Type.Enum,
    values: [
      :amendment,
      :modification,
      :commencement,
      :extent_editorial
    ]
end
