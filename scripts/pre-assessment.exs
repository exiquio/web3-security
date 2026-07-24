#!/usr/bin/env elixir

defmodule PreAssessment do
  @questions [
    %{
      category: "Documentation and Planning",
      number: 1,
      title: "Do you have all actors, roles, and privileges documented?",
      detail: "Document who can do what in your system. This includes admin roles, privileged operations, and the scope of each role's permissions."
    },
    %{
      category: "Documentation and Planning",
      number: 2,
      title: "Do you keep documentation of all external services, contracts, and oracles you rely on?",
      detail: "Maintain an up-to-date list of all external dependencies, including third-party contracts, oracles, bridges, and off-chain services your system interacts with."
    },
    %{
      category: "Documentation and Planning",
      number: 3,
      title: "Do you have a written and tested incident response plan?",
      detail: "Have a documented plan for responding to security incidents. Test it regularly through tabletop exercises."
    },
    %{
      category: "Documentation and Planning",
      number: 4,
      title: "Do you document the best ways to attack your system?",
      detail: "Maintain a threat model that identifies potential attack vectors. Update it as your system evolves."
    },
    %{
      category: "Personnel and Access Control",
      number: 5,
      title: "Do you perform identity verification and background checks on all employees?",
      detail: "Verify the identity of team members, especially those with access to privileged systems or keys."
    },
    %{
      category: "Personnel and Access Control",
      number: 6,
      title: "Do you have a team member with security defined in their role?",
      detail: "Assign explicit security responsibilities to at least one team member. Security should not be an afterthought."
    },
    %{
      category: "Personnel and Access Control",
      number: 7,
      title: "Do you require hardware security keys for production systems?",
      detail: "Use hardware security keys (like YubiKeys) for accessing production systems and critical infrastructure."
    },
    %{
      category: "Personnel and Access Control",
      number: 8,
      title: "Does your key management system require multiple humans and physical steps?",
      detail: "Implement multi-signature schemes and physical security measures for critical operations. No single person should be able to compromise the system."
    },
    %{
      category: "Technical Security",
      number: 9,
      title: "Do you define key invariants for your system and test them on every commit?",
      detail: "Identify the properties that must always hold true in your system and verify them automatically. Use tools like Echidna or Medusa to test invariants continuously."
    },
    %{
      category: "Technical Security",
      number: 10,
      title: "Do you use the best automated tools to discover security issues in your code?",
      detail: "Integrate security tools into your development workflow: Slither for static analysis; Echidna or Medusa for fuzzing."
    },
    %{
      category: "Technical Security",
      number: 11,
      title: "Do you undergo external audits and maintain a vulnerability disclosure or bug bounty program?",
      detail: "Get independent security reviews before major releases. Maintain a way for security researchers to responsibly report vulnerabilities."
    },
    %{
      category: "Technical Security",
      number: 12,
      title: "Have you considered and mitigated avenues for abusing users of your system?",
      detail: "Think beyond technical exploits. Consider how your system could be used to harm users through phishing, social engineering, or economic attacks."
    }
  ]

  @categories ["Documentation and Planning", "Personnel and Access Control", "Technical Security"]

  def run(["generate"]) do
    content = build_markdown(:generate, [])
    File.write!("pre-assessment-questionaire.md", content)
    IO.puts("Written pre-assessment-questionaire.md")
  end

  def run(["assess"]) do
    answers = Enum.map(@questions, fn q ->
      IO.puts("\n--- Question #{q.number} ---")
      IO.puts("#{q.title}")
      IO.puts("> #{q.detail}")
      answer = prompt_yes_no()
      IO.puts("Optional notes (press Enter to skip):")
      notes = IO.gets("> ") |> String.trim()
      %{question: q, answer: answer, notes: notes}
    end)

    content = build_markdown(:assess, answers)
    File.write!("pre-assessment-questionaire.md", content)
    IO.puts("\nWritten pre-assessment-questionaire.md")
  end

  def run(_) do
    IO.puts("Usage: elixir pre-assessment.exs [generate|assess]")
    IO.puts("       ./pre-assessment.exs [generate|assess]")
    IO.puts("  generate  - Output a blank pre-assessment-questionaire.md")
    IO.puts("  assess    - Interactive questionnaire walkthrough")
  end

  defp prompt_yes_no do
    input = IO.gets("Answer (y/n): ") |> String.trim() |> String.downcase()

    case input do
      "y" -> :yes
      "n" -> :no
      _ ->
        IO.puts("Invalid input. Please enter 'y' or 'n'.")
        prompt_yes_no()
    end
  end

  defp build_markdown(:generate, _answers) do
    date = format_date()
    lines = [
      "# Pre-Assessment Questionnaire — REKT Test",
      "",
      "**Date:** #{date}",
      "**Assessed by:** [Name]",
      ""
    ]

    @categories
    |> Enum.reduce(lines, fn category, acc ->
      acc ++ ["## #{category}", ""] ++
        (@questions
         |> Enum.filter(fn q -> q.category == category end)
         |> Enum.flat_map(fn q -> format_question_generate(q) end))
    end)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  defp build_markdown(:assess, answers) do
    date = format_date()
    lines = [
      "# Pre-Assessment Questionnaire — REKT Test",
      "",
      "**Date:** #{date}",
      "**Assessed by:** [Name]",
      ""
    ]

    @categories
    |> Enum.reduce(lines, fn category, acc ->
      acc ++ ["## #{category}", ""] ++
        (answers
         |> Enum.filter(fn a -> a.question.category == category end)
         |> Enum.flat_map(fn a -> format_question_assess(a) end))
    end)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  defp format_question_generate(q) do
    [
      "### #{q.number}. #{q.title}",
      "> #{q.detail}",
      "- [ ] Yes",
      "- [ ] No",
      "[Answer notes]",
      ""
    ]
  end

  defp format_question_assess(a) do
    q = a.question
    yes_checked = if a.answer == :yes, do: "[x]", else: "[ ]"
    no_checked  = if a.answer == :no, do: "[x]", else: "[ ]"
    notes = if a.notes == "", do: "[Answer notes]", else: a.notes

    [
      "### #{q.number}. #{q.title}",
      "> #{q.detail}",
      "- #{yes_checked} Yes",
      "- #{no_checked} No",
      notes,
      ""
    ]
  end

  defp format_date do
    {{y, m, d}, _} = :calendar.local_time()
    "#{y}-#{pad(m)}-#{pad(d)}"
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: Integer.to_string(n)
end

PreAssessment.run(System.argv())
