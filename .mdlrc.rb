# frozen_string_literal: true

all

exclude_rule "MD003"
exclude_rule "MD004"
exclude_rule "MD005" # When using 2 spaces for MD007, this must be disabled
exclude_rule "MD006"
exclude_rule "MD014"
exclude_rule "MD024"
exclude_rule "MD026"
exclude_rule "MD030"
exclude_rule "MD033"
exclude_rule "MD034" # TODO: add <brackets> around bare URLs
exclude_rule "MD036"
exclude_rule "MD040"
exclude_rule "MD041"

# rule "MD003", style: :setext_with_atx
# rule "MD004", style: :sublist
rule "MD007", indent: 2
rule "MD013", line_length: 2000, ignore_code_blocks: true
# rule "MD024", allow_different_nesting: true # This did not work as intended, see action_cable_overview.md
rule "MD029", style: :ordered
# rule "MD046", style: :consistent # default (:fenced)
