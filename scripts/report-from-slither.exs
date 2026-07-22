#!/usr/bin/env elixir
# Ensure the Jason JSON library is available.
# Requires Elixir 1.12 or later for Mix.install/1.
Mix.install([:jason])

defmodule SlitherReport do
  @moduledoc """
  Reads a Slither JSON output file and produces a clean, structured
  Markdown report suitable for security audit reviews.

  Features:
    - Summary table with severity counts
    - Interactive checkboxes (- [ ]) for tracking review progress
    - Findings grouped by severity (High -> Medium -> Low -> Informational -> Optimization)
    - Affected code list filtered to *your* code only (dependencies excluded)
    - Deduplicated code locations with truncation for very long lists
    - Collapsible Slither-native Markdown detail blocks
    - Table of contents with anchor links
    - Robust nil/empty/malformed data handling throughout
    - Non-fatal warnings on stderr when JSON shape deviates from expectations
  """

  # ---------------------------------------------------------------
  # Severity ordering for sorting (lower number = more critical)
  # ---------------------------------------------------------------
  @severity_order %{
    "High" => 1,
    "Medium" => 2,
    "Low" => 3,
    "Informational" => 4,
    "Optimization" => 5
  }

  # Maximum number of affected-code entries to show before truncating.
  @max_affected_entries 15

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  @doc """
  Entry point - parses arguments, reads JSON, builds report, writes output.
  """
  def main(args \\ System.argv()) do
    {input_path, output_path} = parse_args(args)

    raw = read_json!(input_path)
    warn_if_slither_error(raw)

    detectors =
      raw
      |> extract_detectors()
      |> filter_valid()

    report_md = build_report(detectors)
    File.write!(output_path, report_md)
    IO.puts("Report written to #{output_path}")
  end

  # -------------------------------------------------------------------
  # Argument parsing
  # -------------------------------------------------------------------

  defp parse_args(args) do
    case args do
      [input] ->
        {input, "slither_report.md"}

      [input, output] ->
        {input, output}

      _ ->
        IO.puts(:stderr, "Usage: elixir report-from-slither.exs <input.json> [output.md]")
        System.halt(1)
    end
  end

  # -------------------------------------------------------------------
  # File I/O & JSON decoding
  # -------------------------------------------------------------------

  @doc """
  Reads and decodes a JSON file. Halts the program if the file is missing
  or the content is not valid JSON.
  """
  def read_json!(path) do
    unless File.exists?(path) do
      IO.puts(:stderr, "Error: file not found - #{path}")
      System.halt(1)
    end

    case Jason.decode(File.read!(path)) do
      {:ok, data} ->
        data

      {:error, reason} ->
        IO.puts(:stderr, "Error: invalid JSON - #{inspect(reason)}")
        System.halt(1)
    end
  end

  # -------------------------------------------------------------------
  # Top-level JSON sanity checks
  # -------------------------------------------------------------------

  # If Slither reported an error or success=false, print a warning
  # but continue processing - there may still be partial results.
  defp warn_if_slither_error(json) when is_map(json) do
    if Map.get(json, "success") == false do
      IO.warn("Slither reported success=false - results may be incomplete")
    end

    error = json["error"]

    if is_binary(error) and error != "" do
      IO.warn("Slither reported an error: #{error}")
    end
  end

  defp warn_if_slither_error(_), do: :ok

  # -------------------------------------------------------------------
  # Safe detector extraction - handles many Slither JSON shapes
  # -------------------------------------------------------------------

  @doc """
  Slither may embed detectors under `results` > `detectors`, directly
  under a `detectors` key, or return a bare list. This function
  normalises all those cases to a plain list.
  """
  def extract_detectors(json) do
    # The canonical expected shape
    expected = is_map(json) and Map.has_key?(json, "success") and Map.has_key?(json, "results")

    cond do
      expected ->
        get_in(json, ["results", "detectors"]) || []

      # Alternative: {"results": {"detectors": [...]}}
      is_map(json) and Map.has_key?(json, "results") ->
        IO.warn("JSON structure: missing top-level 'success' key - non-standard Slither output")
        get_in(json, ["results", "detectors"]) || []

      # Direct "detectors" key
      is_map(json) and Map.has_key?(json, "detectors") ->
        IO.warn(
          "JSON structure: detectors found under top-level 'detectors' key, " <>
            "not 'results.detectors' - non-standard Slither output"
        )

        json["detectors"]

      # Bare list
      is_list(json) ->
        IO.warn(
          "JSON structure: received a bare list instead of an object - " <>
            "non-standard Slither output"
        )

        json

      # Single finding object (edge case)
      is_map(json) and (Map.has_key?(json, "check") or Map.has_key?(json, "impact")) ->
        IO.warn(
          "JSON structure: received a single finding instead of a list - " <>
            "non-standard Slither output"
        )

        [json]

      true ->
        IO.puts(:stderr, "Error: unrecognised top-level JSON structure.")
        dump_structure(json)
        System.halt(1)
    end
  end

  # Prints the top-level keys (or type) to help diagnose an unknown format.
  defp dump_structure(data) do
    if is_map(data) do
      keys = data |> Map.keys() |> Enum.map(&inspect/1) |> Enum.join(", ")
      IO.puts(:stderr, "Top-level keys: [#{keys}]")
      IO.puts(:stderr, "Please adjust extract_detectors/1 to handle this shape.")
    else
      IO.puts(:stderr, "Unexpected type: #{inspect(data)}")
    end
  end

  # -------------------------------------------------------------------
  # Data validation - strip nil / non-map entries
  # -------------------------------------------------------------------

  @doc """
  Removes nil entries and non-map items from the detector list.
  Warns on stderr when entries were discarded so you know the data
  was malformed.
  """
  def filter_valid(detectors) when is_list(detectors) do
    {valid, invalid_count} =
      detectors
      |> Enum.reduce({[], 0}, fn det, {acc, bad} ->
        if is_map(det) do
          {[det | acc], bad}
        else
          {acc, bad + 1}
        end
      end)

    if invalid_count > 0 do
      IO.warn(
        "Discarded #{invalid_count} non-map detector " <>
          "entr#{if invalid_count == 1, do: "y", else: "ies"} - " <>
          "Slither may have emitted malformed output"
      )
    end

    Enum.reverse(valid)
  end

  def filter_valid(_), do: []

  # -------------------------------------------------------------------
  # Build the full Markdown report
  # -------------------------------------------------------------------

  @doc """
  Groups detectors by severity, produces summary statistics, a table of
  contents, and renders each finding in a consistent, easy-to-scan format.
  """
  def build_report([]) do
    IO.warn("No detector findings to report - the scan may have produced no results")

    """
    # Slither Static Analysis Report

    Generated on #{Date.utc_today()}

    ## Summary

    - **Total findings:** 0

    _No issues were detected by Slither._
    """
  end

  def build_report(detectors) do
    grouped = group_by_severity(detectors)
    severity_order = Map.keys(grouped) |> Enum.sort_by(&Map.get(@severity_order, &1, 99))

    [
      report_header(),
      "<!-- markdownlint-disable MD013 MD033 MD034 -->",
      toc_section(grouped, severity_order),
      summary_section(grouped, severity_order),
      findings_sections(grouped, severity_order)
    ]
    |> Enum.join("\n")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
  end

  # -------------------------------------------------------------------
  # REPORT HEADER
  # -------------------------------------------------------------------

  defp report_header do
    """
    # Slither Static Analysis Report

    Generated on #{Date.utc_today()}
    """
  end

  # -------------------------------------------------------------------
  # TABLE OF CONTENTS (with checkboxes)
  # -------------------------------------------------------------------

  defp toc_section(grouped, severity_order) do
    entries =
      severity_order
      |> Enum.flat_map(fn severity ->
        detectors = grouped[severity] || []

        detectors
        |> Enum.sort_by(&safely(&1, "check", "zzz"))
        |> Enum.with_index(1)
        |> Enum.map(fn {det, idx} ->
          check = safely(det, "check", "unknown")
          anchor = "#{severity_slug(severity)}-#{idx}-#{check}"
          "- [ ] [#{check}](##{anchor})"
        end)
      end)

    if entries == [] do
      ""
    else
      """
      ## Table of Contents

      #{Enum.join(entries, "\n")}

      ---
      """
    end
  end

  # -------------------------------------------------------------------
  # SUMMARY TABLE
  # -------------------------------------------------------------------

  defp summary_section(grouped, severity_order) do
    total = grouped |> Map.values() |> List.flatten() |> length()

    table_rows =
      severity_order
      |> Enum.map(fn severity ->
        count = Integer.to_string(Enum.count(grouped[severity] || []))
        {"**#{severity}**", count}
      end)

    """
    ## Summary

    - **Total findings:** #{total}

    #{format_table("Severity", "Count", table_rows)}

    ---
    """
  end

  # -------------------------------------------------------------------
  # GROUPED FINDINGS SECTIONS
  # -------------------------------------------------------------------

  defp findings_sections(grouped, severity_order) do
    severity_order
    |> Enum.map(fn severity ->
      detectors = grouped[severity] || []
      render_severity_section(severity, detectors)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp render_severity_section(_severity, []), do: ""

  defp render_severity_section(severity, detectors) do
    heading = "## #{severity} Severity Findings"

    body =
      detectors
      |> Enum.sort_by(&safely(&1, "check", "zzz"))
      |> Enum.with_index(1)
      |> Enum.map(fn {detector, idx} ->
        render_detector(detector, idx, severity)
      end)
      |> Enum.join("\n")

    [heading, body] |> Enum.join("\n\n")
  end

  # -------------------------------------------------------------------
  # RENDER A SINGLE DETECTOR (with checkbox and field-missing warnings)
  # -------------------------------------------------------------------

  defp render_detector(detector, idx, severity) do
    check = safely(detector, "check", "unknown")
    impact = safely(detector, "impact", severity)
    confidence = safely(detector, "confidence", "Unknown")
    description = clean_description(safely(detector, "description", nil))
    elements = safely(detector, "elements", [])
    slither_md = safely(detector, "markdown", nil)

    # Warn on missing fields so you know Slither's output schema changed
    warn_missing_fields(detector, check, idx)

    # Build a stable anchor for TOC linking
    anchor = "#{severity_slug(severity)}-#{idx}-#{check}"

    prop_table =
      format_table("Property", "Value", [
        {"Impact", impact},
        {"Confidence", confidence}
      ])

    details = render_slither_details(slither_md)
    details_block = if details != "", do: ["", details], else: []

    [
      "### <a id=\"#{anchor}\"></a>- [ ] #{idx}. #{check}",
      "",
      prop_table,
      "",
      "**Description:** #{description}",
      "",
      render_affected_code(elements, check)
    ] ++
      details_block
    |> Enum.join("\n")
  end

  # Warns (once per missing field) when a detector lacks expected keys.
  # Slither may add/rename fields in future versions.
  @expected_fields ~w(check impact confidence description elements markdown id)
  defp warn_missing_fields(detector, check, idx) do
    if is_map(detector) do
      missing =
        @expected_fields
        |> Enum.reject(&Map.has_key?(detector, &1))
        |> Enum.sort()

      unless missing == [] do
        fields = Enum.join(missing, ", ")
        IO.warn("[#{check} ##{idx}] missing expected field(s): #{fields}")
      end
    end
  end

  # -------------------------------------------------------------------
  # DESCRIPTION CLEANUP
  # -------------------------------------------------------------------

  # Collapses all whitespace (including newlines) into single spaces,
  # trims, and produces a single-line description safe for inline use.
  defp clean_description(nil), do: "No description provided."

  defp clean_description(str) when is_binary(str) do
    oneline =
      str
      |> String.replace("\r\n", " ")
      |> String.replace("\n", " ")
      |> String.replace("\t", " ")
      |> String.replace(~r/ +/, " ")
      |> String.trim()
      |> String.replace("_", "\\_")

    if oneline == "", do: "No description provided.", else: oneline
  end

  defp clean_description(_), do: "No description provided."

  # -------------------------------------------------------------------
  # AFFECTED CODE LIST
  # -------------------------------------------------------------------

  # Only shows elements from the user's own code (not dependencies),
  # deduplicates by {file, lines, name}, and truncates long lists.
  # Warns when own-code filtering removed everything or when truncating.
  defp render_affected_code([], _check), do: "_No code elements reported._"
  defp render_affected_code(nil, _check), do: "_No code elements reported._"

  defp render_affected_code(elements, check) when is_list(elements) do
    own_code =
      elements
      |> Enum.filter(&own_code?/1)
      |> Enum.uniq_by(fn el ->
        {extract_file(el), extract_lines(el), extract_name(el)}
      end)

    # If nothing remains after filtering, fall back to the original list
    {filtered, fell_back} =
      if own_code == [] do
        IO.warn(
          "[#{check}] all affected-code elements are from dependencies - " <>
            "showing full list instead"
        )

        {elements, true}
      else
        {own_code, false}
      end

    total = length(filtered)
    shown = Enum.take(filtered, @max_affected_entries)

    if total > @max_affected_entries do
      IO.warn(
        "[#{check}] truncating affected-code list: " <>
          "#{total} entries, showing #{@max_affected_entries}"
      )
    end

    items =
      shown
      |> Enum.map(fn el ->
        file = extract_file(el)
        lines_str = extract_lines(el)
        name = extract_name(el)

        cond do
          file != "" and lines_str != "" and name != "" ->
            "- **`#{file}:#{lines_str}`** - `#{name}`"

          file != "" and lines_str != "" ->
            "- **`#{file}:#{lines_str}`**"

          file != "" ->
            "- `#{file}`"

          true ->
            "- _Unknown location_"
        end
      end)

    truncation =
      if total > @max_affected_entries do
        "\n- _... and #{total - @max_affected_entries} more (see Full Slither Output below)_"
      else
        ""
      end

    # If we fell back to dependencies, note it in the report
    dep_note =
      if fell_back do
        "\n\n_Note: all locations above are from dependency files._"
      else
        ""
      end

    ["**Affected code:**", :blank, Enum.join(items, "\n"), truncation, dep_note]
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn :blank -> ""; other -> other end)
    |> Enum.join("\n")
  end

  defp render_affected_code(_, _check), do: "_No code elements reported._"

  # Returns true if the element is NOT from a dependency file.
  defp own_code?(element) when is_map(element) do
    case get_in(element, ["source_mapping", "is_dependency"]) do
      true -> false
      _ -> true
    end
  end

  defp own_code?(_), do: true

  # -------------------------------------------------------------------
  # SLITHER DETAILS (collapsible)
  # -------------------------------------------------------------------

  defp render_slither_details(nil), do: ""
  defp render_slither_details(""), do: ""

  defp render_slither_details(markdown) when is_binary(markdown) do
    cleaned =
      markdown
      |> String.replace("\t", "  ")
      |> String.trim_trailing()

    """
    <details>
    <summary><b>🔍 Full Slither Output</b></summary>

    <!-- markdownlint-disable MD007 MD032 MD037 -->

    #{cleaned}

    <!-- markdownlint-enable MD007 MD032 MD037 -->

    </details>
    """
  end

  defp render_slither_details(_), do: ""

  # -------------------------------------------------------------------
  # Helpers: extract filename, lines, element name
  # -------------------------------------------------------------------

  # Guard against nil / non-map elements
  defp extract_file(el) when is_map(el) do
    sm = el["source_mapping"]

    cond do
      is_map(sm) and is_binary(sm["filename_short"]) ->
        sm["filename_short"]

      is_map(sm) and is_binary(sm["filename_relative"]) ->
        sm["filename_relative"]

      is_map(sm) and is_binary(sm["filename_absolute"]) ->
        Path.basename(sm["filename_absolute"])

      true ->
        ""
    end
  end

  defp extract_file(_), do: ""

  defp extract_lines(el) when is_map(el) do
    sm = el["source_mapping"]

    if is_map(sm) do
      lines = sm["lines"]

      if is_list(lines) and length(lines) > 0 do
        min = Enum.min(lines)
        max = Enum.max(lines)
        if min == max, do: "L#{min}", else: "L#{min}-L#{max}"
      end
    end
  end

  defp extract_lines(_), do: nil

  defp extract_name(el) when is_map(el) do
    name = el["name"]
    if is_binary(name), do: name
  end

  defp extract_name(_), do: nil

  # -------------------------------------------------------------------
  # Group detectors by severity (fallback to "Informational")
  # -------------------------------------------------------------------

  defp group_by_severity(detectors) do
    detectors
    |> Enum.group_by(fn det ->
      severity = safely(det, "impact", "Informational")

      unless Map.has_key?(@severity_order, severity) do
        check = safely(det, "check", "?")
        IO.warn("[#{check}] unknown severity '#{severity}' - falling back to 'Informational'")
      end

      if Map.has_key?(@severity_order, severity), do: severity, else: "Informational"
    end)
    |> Map.new(fn {k, v} -> {k, v} end)
  end

  # -------------------------------------------------------------------
  # Utility helpers
  # -------------------------------------------------------------------

  # Safe map access - returns default if key is missing or map is nil.
  defp safely(nil, _key, default), do: default
  defp safely(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp safely(_, _key, default), do: default

  # Builds a properly aligned two-column Markdown table.
  # Each row is a {col1, col2} tuple. Column widths are computed from
  # headers and content so the separator and content pipes all align.
  defp format_table(header1, header2, rows) do
    col1_width =
      [String.length(header1) | Enum.map(rows, fn {c1, _} -> String.length(c1) end)]
      |> Enum.max()
      |> max(3)

    col2_width =
      [String.length(header2) | Enum.map(rows, fn {_, c2} -> String.length(c2) end)]
      |> Enum.max()
      |> max(3)

    pad = fn str, width ->
      str <> String.duplicate(" ", width - String.length(str))
    end

    [
      "| #{pad.(header1, col1_width)} | #{pad.(header2, col2_width)} |",
      "| #{String.duplicate("-", col1_width)} | #{String.duplicate("-", col2_width)} |",
      Enum.map(rows, fn {c1, c2} ->
        "| #{pad.(c1, col1_width)} | #{pad.(c2, col2_width)} |"
      end)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  # Converts a severity string to a URL-safe slug.
  defp severity_slug(str) when is_binary(str) do
    str |> String.downcase() |> String.replace(" ", "-")
  end

  defp severity_slug(_), do: "unknown"
end

# -----------------------------------------------------------------
# Execute the script
# -----------------------------------------------------------------
SlitherReport.main()
